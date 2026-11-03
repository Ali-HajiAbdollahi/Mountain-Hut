// MH-07 Reserve for an hiker — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addEmployee, addSlot, loginAs, PASSWORD } from '../helpers/app.js';

let ctx, lunch, employee, staff, sara;

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addHiker(ctx);
  sara = addHiker(ctx, { name: 'Sara Verdi', email: 'sara@mail.it', phone: '3339998888' });
  employee = addEmployee(ctx);
  lunch = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 4, 2: 6 });
  staff = await loginAs(ctx, 'elena@hut.it');
});
afterEach(() => {
  vi.useRealTimers();
});

const reserve = (hiker, extra = {}) =>
  staff.post('/api/staff/bookings').send({ hiker, tsID: lunch, n_people: 3, ...extra });

describe('GET /api/staff/hikers', () => {
  it.each([['name', 'verdi'], ['phone', '99988'], ['email', 'sara@']])(
    'finds an existing hiker by %s', async (_, query) => {
      const res = await staff.get('/api/staff/hikers').query({ query });
      expect(res.status).toBe(200);
      expect(res.body.hikers).toEqual([expect.objectContaining({ uID: sara.uID, name: 'Sara Verdi' })]);
    });

  it('never returns employees or password data', async () => {
    const res = await staff.get('/api/staff/hikers').query({ query: 'elena' });
    expect(res.body.hikers).toEqual([]);
    const all = await staff.get('/api/staff/hikers').query({ query: 'mail.it' });
    expect(all.body.hikers.every(h => !('password' in h) && !('salt' in h))).toBe(true);
  });

  it('requires at least 2 characters', async () => {
    expect((await staff.get('/api/staff/hikers').query({ query: 's' })).status).toBe(400);
  });

  it('is reserved to employees', async () => {
    const marco = await loginAs(ctx, 'marco@mail.it');
    expect((await marco.get('/api/staff/hikers').query({ query: 'sara' })).status).toBe(403);
    expect((await request(ctx.app).get('/api/staff/hikers').query({ query: 'sara' })).status).toBe(401);
  });
});

describe('POST /api/staff/bookings', () => {
  it('books for a hiker already in the system, who then sees it in their bookings', async () => {
    const res = await reserve({ mode: 'existing', uID: sara.uID });
    expect(res.status).toBe(201);
    expect(res.body.booking).toMatchObject({ uID: sara.uID, contact_name: 'Sara Verdi', created_by: employee.uID });

    const saraAgent = await loginAs(ctx, 'sara@mail.it');
    expect((await saraAgent.get('/api/bookings')).body).toHaveLength(1);
  });

  it('quick entry: temporary hiker with name and optional phone, without an account', async () => {
    const res = await reserve({ mode: 'temporary', name: 'Rossi Group', phone: '3335550000' });
    expect(res.status).toBe(201);
    expect(res.body.booking).toMatchObject({ uID: null, contact_name: 'Rossi Group', contact_phone: '3335550000' });
    expect(ctx.db.prepare("SELECT COUNT(*) AS n FROM users WHERE name = 'Rossi Group'").get().n).toBe(0);
  });

  it('full details: creates a regular hiker profile that can then log in', async () => {
    const res = await reserve({
      mode: 'register', name: 'Luca Neri', email: 'luca@mail.it', phone: '3334440000', password: PASSWORD });
    expect(res.status).toBe(201);
    expect(res.body.booking.uID).toEqual(expect.any(Number));

    const login = await request(ctx.app).post('/api/sessions').send({ email: 'luca@mail.it', password: PASSWORD });
    expect(login.status).toBe(200);
    expect(login.body.role).toBe('hiker');
  });

  it('full details: an email already registered is a conflict and no booking is made', async () => {
    const res = await reserve({
      mode: 'register', name: 'Sara 2', email: 'sara@mail.it', phone: '333', password: PASSWORD });
    expect(res.status).toBe(409);
    expect(ctx.db.prepare('SELECT COUNT(*) AS n FROM bookings').get().n).toBe(0);
  });

  it('uses the same seat allocation and capacity rules as a web booking', async () => {
    const res = await reserve({ mode: 'temporary', name: 'Big Group' }, { n_people: 11 });
    expect(res.status).toBe(409);
  });

  it('keeps one booking per slot for registered hikers', async () => {
    await reserve({ mode: 'existing', uID: sara.uID });
    expect((await reserve({ mode: 'existing', uID: sara.uID })).status).toBe(409);
  });

  it('saves the party requirements', async () => {
    const res = await reserve({ mode: 'temporary', name: 'Rossi' },
      { requirements: [{ description: 'celiac', allergy: true, n_people: 1 }] });
    expect(res.body.booking.requirements).toMatchObject([{ description: 'celiac', allergy: true }]);
  });

  it('returns 404 for an unknown hiker and 400 for an invalid mode', async () => {
    expect((await reserve({ mode: 'existing', uID: 999 })).status).toBe(404);
    expect((await reserve({ mode: 'guest', name: 'x' })).status).toBe(400);
  });

  it('is reserved to employees', async () => {
    const marco = await loginAs(ctx, 'marco@mail.it');
    const res = await marco.post('/api/staff/bookings')
      .send({ hiker: { mode: 'temporary', name: 'x' }, tsID: lunch, n_people: 2 });
    expect(res.status).toBe(403);
  });
});
