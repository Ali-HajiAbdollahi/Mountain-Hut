// MH-03 Receive confirmation — integration tests (HTTP API + in-memory SQLite, fake mail)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addSlot, loginAs } from '../helpers/app.js';

let ctx, lunch, marco;

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addHiker(ctx);
  addHiker(ctx, { name: 'Sara Verdi', email: 'sara@mail.it' });
  lunch = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 4, 2: 6 });
  marco = await loginAs(ctx, 'marco@mail.it');
});
afterEach(() => {
  vi.useRealTimers();
});

const book = (agent, extra = {}) => agent.post('/api/bookings').send({ tsID: lunch, n_people: 3, ...extra });

describe('confirmation email after booking', () => {
  it('is sent to the hiker who made the reservation', async () => {
    const res = await book(marco);
    expect(res.body.notification).toEqual({ status: 'accepted', messageId: 'test-1' });
    expect(ctx.mail.sent).toHaveLength(1);
    expect(ctx.mail.sent[0].to).toBe('marco@mail.it');
  });

  it('contains reference, date and slot, party size, requirements and hiker name', async () => {
    const res = await book(marco, { requirements: [{ description: 'peanut allergy', allergy: true, n_people: 1 }] });
    const { text } = ctx.mail.sent[0];
    expect(text).toContain(res.body.booking.reference);
    expect(text).toContain('2026-12-01 12:00');
    expect(text).toContain('2026-12-01 13:00');
    expect(text).toContain('Party size: 3');
    expect(text).toContain('peanut allergy');
    expect(text).toContain('Marco Bianchi');
  });

  it('is not sent when the booking fails', async () => {
    await book(marco, { n_people: 50 });
    expect(ctx.mail.sent).toHaveLength(0);
  });

  it('a mail failure does not cancel the booking', async () => {
    ctx.mail.send = async () => ({ status: 'failed' });
    const res = await book(marco);
    expect(res.status).toBe(201);
    expect(res.body.notification).toEqual({ status: 'failed' });
    expect((await marco.get(`/api/bookings/${res.body.booking.bID}`)).status).toBe(200);
  });
});

describe('POST /api/bookings/:id/confirmation', () => {
  it('sends the confirmation again', async () => {
    const { body } = await book(marco);
    const res = await marco.post(`/api/bookings/${body.booking.bID}/confirmation`).send({});
    expect(res.status).toBe(200);
    expect(res.body.bookingReference).toBe(body.booking.reference);
    expect(ctx.mail.sent).toHaveLength(2);
  });

  it('cannot be used on the booking of another hiker', async () => {
    const { body } = await book(marco);
    const sara = await loginAs(ctx, 'sara@mail.it');
    expect((await sara.post(`/api/bookings/${body.booking.bID}/confirmation`).send({})).status).toBe(404);
  });
});

describe('GET /api/bookings/:id', () => {
  it('returns the details of the hiker\'s own booking', async () => {
    const { body } = await book(marco, { requirements: [{ description: 'vegan', allergy: false }] });
    const res = await marco.get(`/api/bookings/${body.booking.bID}`);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      reference: `MH-${body.booking.bID}`, n_people: 3, start_time: '2026-12-01 12:00',
      requirements: [{ description: 'vegan', allergy: false, n_people: null }],
    });
  });

  it('hides bookings of other hikers as not found', async () => {
    const { body } = await book(marco);
    const sara = await loginAs(ctx, 'sara@mail.it');
    expect((await sara.get(`/api/bookings/${body.booking.bID}`)).status).toBe(404);
  });

  it('requires login', async () => {
    expect((await request(ctx.app).get('/api/bookings/1')).status).toBe(401);
  });
});
