// MH-08 Cancel a booking — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import {
  createTestContext, freezeTime, addHiker, addEmployee, addSlot, loginAs, seatsOf,
} from '../helpers/app.js';

let ctx, lunch, marco, sara, bID;

const availability = partySize => request(ctx.app).get('/api/availability')
  .query({ date: '2026-12-01', time: '12:00', partySize });
const requirementsOf = id => ctx.db.prepare(
  'SELECT COUNT(*) AS n FROM booking_requirements WHERE bID = ?').get(id).n;

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addHiker(ctx);
  addHiker(ctx, { name: 'Sara Verdi', email: 'sara@mail.it', phone: '3339998888' });
  // 6 seats in total: Marco's party of 6 fills the slot
  lunch = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 4, 2: 2 });
  marco = await loginAs(ctx, 'marco@mail.it');
  sara = await loginAs(ctx, 'sara@mail.it');
  const res = await marco.post('/api/bookings').send({
    tsID: lunch, n_people: 6, requirements: [{ description: 'peanut allergy', allergy: true, n_people: 1 }] });
  bID = res.body.booking.bID;
});
afterEach(() => {
  vi.useRealTimers();
});

describe('DELETE /api/bookings/:id', () => {
  it('cancels the hiker\'s own booking, which no longer appears in their bookings', async () => {
    const res = await marco.delete(`/api/bookings/${bID}`);
    expect(res.status).toBe(204);
    expect((await marco.get('/api/bookings')).body).toEqual([]);
    expect((await marco.get(`/api/bookings/${bID}`)).status).toBe(404);
  });

  it('releases the seats and removes the requirements of the booking', async () => {
    expect(seatsOf(ctx, bID)).toEqual({ 1: 4, 2: 2 });
    expect(requirementsOf(bID)).toBe(1);
    await marco.delete(`/api/bookings/${bID}`);
    expect(seatsOf(ctx, bID)).toEqual({});
    expect(requirementsOf(bID)).toBe(0);
  });

  it('makes the places available to other guests (MH-103)', async () => {
    expect((await availability(1)).body.available).toBe(false);
    await marco.delete(`/api/bookings/${bID}`);
    expect((await availability(6)).body.available).toBe(true);
    const res = await sara.post('/api/bookings').send({ tsID: lunch, n_people: 6 });
    expect(res.status).toBe(201);
  });

  it('only frees the seats of the cancelled booking', async () => {
    const dinner = addSlot(ctx, '2026-12-01 19:00', '2026-12-01 20:00', { 1: 4 });
    const other = (await sara.post('/api/bookings').send({ tsID: dinner, n_people: 3 })).body.booking.bID;
    await marco.delete(`/api/bookings/${bID}`);
    expect(seatsOf(ctx, other)).toEqual({ 1: 3 });
    expect((await sara.get('/api/bookings')).body).toHaveLength(1);
  });

  it('has no time constraint: it works less than 2 hours before the meal and after it started', async () => {
    freezeTime(new Date('2026-12-01T11:30:00Z')); // 12:30 in Rome, the slot has started
    expect((await marco.delete(`/api/bookings/${bID}`)).status).toBe(204);
  });

  it('hides the bookings of other hikers as not found, and keeps them', async () => {
    expect((await sara.delete(`/api/bookings/${bID}`)).status).toBe(404);
    expect(seatsOf(ctx, bID)).toEqual({ 1: 4, 2: 2 });
  });

  it('returns 404 for an unknown booking and for a booking already cancelled', async () => {
    expect((await marco.delete('/api/bookings/9999')).status).toBe(404);
    await marco.delete(`/api/bookings/${bID}`);
    expect((await marco.delete(`/api/bookings/${bID}`)).status).toBe(404);
  });

  it('returns 400 for an invalid id', async () => {
    expect((await marco.delete('/api/bookings/abc')).status).toBe(400);
  });

  it('requires login', async () => {
    expect((await request(ctx.app).delete(`/api/bookings/${bID}`)).status).toBe(401);
  });

  it('is not available to employees', async () => {
    addEmployee(ctx);
    const staff = await loginAs(ctx, 'elena@hut.it');
    expect((await staff.delete(`/api/bookings/${bID}`)).status).toBe(403);
    expect(seatsOf(ctx, bID)).toEqual({ 1: 4, 2: 2 });
  });

  it('lets a hiker cancel a booking an employee made for them', async () => {
    addEmployee(ctx);
    const staff = await loginAs(ctx, 'elena@hut.it');
    const saraId = ctx.db.prepare("SELECT uID FROM users WHERE email = 'sara@mail.it'").get().uID;
    const dinner = addSlot(ctx, '2026-12-01 19:00', '2026-12-01 20:00', { 1: 4 });
    const res = await staff.post('/api/staff/bookings')
      .send({ hiker: { mode: 'existing', uID: saraId }, tsID: dinner, n_people: 2 });
    expect(res.status).toBe(201);
    expect((await sara.delete(`/api/bookings/${res.body.booking.bID}`)).status).toBe(204);
  });
});
