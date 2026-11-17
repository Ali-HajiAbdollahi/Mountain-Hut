// MH-07 Reserve for an hiker — forced password change and password recovery (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addEmployee, addSlot, loginAs, PASSWORD, NOW } from '../helpers/app.js';

let ctx, staff;
const HOUR = 60 * 60 * 1000;
const NEW_PASSWORD = 'a-brand-new-password';

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addHiker(ctx);
  addEmployee(ctx);
  addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 4 });
  staff = await loginAs(ctx, 'elena@hut.it');
});
afterEach(() => {
  vi.useRealTimers();
});

// An employee books for a new hiker: returns the generated password
async function staffCreatedPassword() {
  const res = await staff.post('/api/staff/bookings').send({
    hiker: { mode: 'register', name: 'Luca Neri', email: 'luca@mail.it', phone: '3334440000' },
    tsID: 1, n_people: 2 });
  expect(res.status).toBe(201);
  return res.body.generatedPassword;
}
const loginLuca = async password => {
  const agent = request.agent(ctx.app);
  const res = await agent.post('/api/sessions').send({ email: 'luca@mail.it', password });
  return { agent, res };
};

describe('account created by an employee', () => {
  it('must change the password before using the app', async () => {
    const { agent, res } = await loginLuca(await staffCreatedPassword());
    expect(res.status).toBe(200);
    expect(res.body.must_change_password).toBe(true);

    const blocked = await agent.get('/api/bookings');
    expect(blocked.status).toBe(403);
    expect(blocked.body.error.code).toBe('PASSWORD_CHANGE_REQUIRED');
    expect((await agent.post('/api/bookings').send({ tsID: 1, n_people: 1 })).status).toBe(403);
    expect((await agent.get('/api/hikes')).status).toBe(403);

    // the session itself stays readable, so the app can tell what to show
    const current = await agent.get('/api/sessions/current');
    expect(current.status).toBe(200);
    expect(current.body.must_change_password).toBe(true);
  });

  it('uses the app normally after changing the password', async () => {
    const generated = await staffCreatedPassword();
    const { agent } = await loginLuca(generated);

    const change = await agent.put('/api/users/current/password')
      .send({ current_password: generated, new_password: NEW_PASSWORD });
    expect(change.status).toBe(200);
    expect(change.body.must_change_password).toBe(false);
    expect(JSON.stringify(change.body)).not.toContain(NEW_PASSWORD);

    const bookings = await agent.get('/api/bookings');
    expect(bookings.status).toBe(200);
    expect(bookings.body).toHaveLength(1);

    // the next login no longer asks for a change; the generated password stopped working
    expect((await loginLuca(generated)).res.status).toBe(401);
    const next = await loginLuca(NEW_PASSWORD);
    expect(next.res.body.must_change_password).toBe(false);
    expect((await next.agent.get('/api/bookings')).status).toBe(200);
  });

  it('a hiker who registers on their own is never asked to change the password', async () => {
    const res = await request(ctx.app).post('/api/sessions').send({ email: 'marco@mail.it', password: PASSWORD });
    expect(res.body.must_change_password).toBe(false);
  });
});

describe('PUT /api/users/current/password', () => {
  it('refuses a wrong current password, a weak or unchanged new password, and keeps the flag', async () => {
    const generated = await staffCreatedPassword();
    const { agent } = await loginLuca(generated);
    const change = body => agent.put('/api/users/current/password').send(body);

    expect((await change({ current_password: 'wrong-password', new_password: NEW_PASSWORD })).status).toBe(400);
    expect((await change({ current_password: generated, new_password: 'short' })).status).toBe(400);
    expect((await change({ current_password: generated, new_password: generated })).status).toBe(400);
    expect((await change({ current_password: generated })).status).toBe(400);
    expect((await change({ current_password: generated, new_password: NEW_PASSWORD, extra: 1 })).status).toBe(400);
    expect((await agent.get('/api/sessions/current')).body.must_change_password).toBe(true);
  });

  it('requires login', async () => {
    const res = await request(ctx.app).put('/api/users/current/password')
      .send({ current_password: PASSWORD, new_password: NEW_PASSWORD });
    expect(res.status).toBe(401);
  });

  it('lets any hiker change their password voluntarily', async () => {
    const marco = await loginAs(ctx, 'marco@mail.it');
    expect((await marco.put('/api/users/current/password')
      .send({ current_password: PASSWORD, new_password: NEW_PASSWORD })).status).toBe(200);
    expect((await request(ctx.app).post('/api/sessions')
      .send({ email: 'marco@mail.it', password: NEW_PASSWORD })).status).toBe(200);
  });
});

describe('password recovery', () => {
  const tokenOf = mail => /Reset code \(to paste in the app\): (\S+)/.exec(mail.text)[1];
  const requestReset = email => request(ctx.app).post('/api/password-resets').send({ email });
  const confirm = (token, new_password = NEW_PASSWORD) =>
    request(ctx.app).post('/api/password-resets/confirm').send({ token, new_password });
  const canLogin = async password =>
    (await request(ctx.app).post('/api/sessions').send({ email: 'marco@mail.it', password })).status === 200;

  it('emails a reset link and lets the hiker choose a new password with it', async () => {
    const res = await requestReset('marco@mail.it');
    expect(res.status).toBe(202);
    expect(ctx.mail.sent).toHaveLength(1);
    const [mail] = ctx.mail.sent;
    expect(mail.to).toBe('marco@mail.it');
    expect(mail.text).toContain('valid for 24 hours');
    expect(mail.text).toMatch(/Reset link: http\S+\?token=/);

    expect((await confirm(tokenOf(mail))).status).toBe(204);
    expect(await canLogin(NEW_PASSWORD)).toBe(true);
    expect(await canLogin(PASSWORD)).toBe(false);
  });

  it('stores only a hash of the token', async () => {
    await requestReset('marco@mail.it');
    const token = tokenOf(ctx.mail.sent[0]);
    const rows = ctx.db.prepare('SELECT * FROM password_resets').all();
    expect(rows).toHaveLength(1);
    expect(JSON.stringify(rows)).not.toContain(token);
    expect(rows[0].token_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(rows[0].expires_at).toBe(new Date(NOW.getTime() + 24 * HOUR).toISOString());
  });

  it('accepts the token until 24 hours after it was issued', async () => {
    await requestReset('marco@mail.it');
    vi.setSystemTime(new Date(NOW.getTime() + 24 * HOUR - 1000));
    expect((await confirm(tokenOf(ctx.mail.sent[0]))).status).toBe(204);
  });

  it('refuses an expired token and leaves the password unchanged', async () => {
    await requestReset('marco@mail.it');
    vi.setSystemTime(new Date(NOW.getTime() + 24 * HOUR + 1000));
    const res = await confirm(tokenOf(ctx.mail.sent[0]));
    expect(res.status).toBe(400);
    expect(await canLogin(PASSWORD)).toBe(true);
    expect(await canLogin(NEW_PASSWORD)).toBe(false);
  });

  it('accepts a token only once', async () => {
    await requestReset('marco@mail.it');
    const token = tokenOf(ctx.mail.sent[0]);
    expect((await confirm(token)).status).toBe(204);
    expect((await confirm(token, 'another-new-password')).status).toBe(400);
    expect(await canLogin(NEW_PASSWORD)).toBe(true);
    expect(await canLogin('another-new-password')).toBe(false);
  });

  it('a newer request invalidates the previous token', async () => {
    await requestReset('marco@mail.it');
    await requestReset('marco@mail.it');
    const [first, second] = ctx.mail.sent.map(tokenOf);
    expect((await confirm(first)).status).toBe(400);
    expect((await confirm(second)).status).toBe(204);
  });

  it('answers in the same way whether the email exists or not, and sends nothing for an unknown one', async () => {
    const known = await requestReset('marco@mail.it');
    const unknown = await requestReset('nobody@mail.it');
    expect(unknown.status).toBe(known.status);
    expect(unknown.body).toEqual(known.body);
    expect(ctx.mail.sent).toHaveLength(1);
    expect(ctx.db.prepare('SELECT COUNT(*) AS n FROM password_resets').get().n).toBe(1);
  });

  it('answers 202 even when the email cannot be delivered', async () => {
    ctx.mail.send = async () => { throw new Error('smtp down'); };
    expect((await requestReset('marco@mail.it')).status).toBe(202);
  });

  it('refuses an unknown token, and a weak password does not use the token up', async () => {
    await requestReset('marco@mail.it');
    const token = tokenOf(ctx.mail.sent[0]);
    expect((await confirm('not-a-real-token')).status).toBe(400);
    expect((await confirm(token, 'short')).status).toBe(400);
    expect((await confirm(token)).status).toBe(204);
  });

  it('validates the request body', async () => {
    expect((await request(ctx.app).post('/api/password-resets').send({})).status).toBe(400);
    expect((await request(ctx.app).post('/api/password-resets').send({ email: 'a@b.it', x: 1 })).status).toBe(400);
    expect((await request(ctx.app).post('/api/password-resets/confirm').send({ new_password: NEW_PASSWORD })).status).toBe(400);
  });

  it('lets an account created by an employee recover access: no password change is required afterwards', async () => {
    await staffCreatedPassword();
    await requestReset('luca@mail.it');
    expect((await confirm(tokenOf(ctx.mail.sent.at(-1)))).status).toBe(204);
    const { agent, res } = await loginLuca(NEW_PASSWORD);
    expect(res.body.must_change_password).toBe(false);
    expect((await agent.get('/api/bookings')).status).toBe(200);
  });

});
