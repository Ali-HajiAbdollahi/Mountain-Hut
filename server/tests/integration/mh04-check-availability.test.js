// MH-04 Check availability — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addSlot, loginAs } from '../helpers/app.js';

let ctx, lunch;
const check = (partySize, time = '12:00', date = '2026-12-01') =>
  request(ctx.app).get('/api/availability').query({ date, time, partySize });

beforeEach(() => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addHiker(ctx);
  lunch = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 2, 2: 2, 3: 2 });
});
afterEach(() => {
  vi.useRealTimers();
});

describe('GET /api/availability', () => {
  it('is public: no login is required', async () => {
    const res = await check(2);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ available: true, partySize: 2, slot: { tsID: lunch } });
  });

  it('example from the story: 6 free seats over 3 tables of 2, party of 6', async () => {
    const res = await check(6);
    expect(res.body.available).toBe(true);
    expect(res.body.allocation).toEqual([
      { table_no: 1, seats: 2 }, { table_no: 2, seats: 2 }, { table_no: 3, seats: 2 }]);
  });

  it('answers no when the party is larger than the free seats', async () => {
    const res = await check(7);
    expect(res.body).toMatchObject({ available: false, allocation: [] });
  });

  it('takes existing bookings into account', async () => {
    const marco = await loginAs(ctx, 'marco@mail.it');
    await marco.post('/api/bookings').send({ tsID: lunch, n_people: 3 });
    expect((await check(3)).body.available).toBe(true);
    expect((await check(4)).body.available).toBe(false);
  });

  it('answers no, without suggesting other slots, when there is no slot at that time', async () => {
    const res = await check(2, '12:30');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ available: false, partySize: 2, slot: null, allocation: [] });
  });

  it('returns 400 for invalid parameters', async () => {
    expect((await check(0)).status).toBe(400);
    expect((await check(2, '12h')).status).toBe(400);
    expect((await check(2, '12:00', '2026/12/01')).status).toBe(400);
    expect((await request(ctx.app).get('/api/availability')).status).toBe(400);
  });

  // [BUG] see the unit test with the same name: availability splits a party over more
  // tables than the real booking (allocateTables) would. Fails until fixed.
  it('[BUG] shows the same tables the booking will actually take', async () => {
    const dinner = addSlot(ctx, '2026-12-01 19:00', '2026-12-01 20:00', { 1: 2, 2: 2, 3: 4 });
    const shown = (await check(5, '19:00')).body.allocation;
    const marco = await loginAs(ctx, 'marco@mail.it');
    const booked = (await marco.post('/api/bookings').send({ tsID: dinner, n_people: 5 })).body.booking.tables;
    expect(shown).toEqual(booked);
  });
});
