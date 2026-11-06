// MH-01 Book a table — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addEmployee, addSlot, loginAs, seatsOf } from '../helpers/app.js';

let ctx, lunch, hikerAgent;

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addHiker(ctx);
  addHiker(ctx, { name: 'Sara Verdi', email: 'sara@mail.it' });
  addEmployee(ctx);
  lunch = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 2, 2: 2, 3: 4, 4: 6 });
  hikerAgent = await loginAs(ctx, 'marco@mail.it');
});
afterEach(() => {
  vi.useRealTimers();
});

describe('POST /api/bookings', () => {
  it('books a table and returns the booking', async () => {
    const res = await hikerAgent.post('/api/bookings').send({ tsID: lunch, n_people: 4 });
    expect(res.status).toBe(201);
    expect(res.headers.location).toBe(`/api/bookings/${res.body.booking.bID}`);
    expect(res.body.booking).toMatchObject({
      tsID: lunch, n_people: 4, contact_name: 'Marco Bianchi', start_time: '2026-12-01 12:00',
      tables: [{ table_no: 3, seats: 4 }],
    });
  });

  it('spreads a large party over as few tables as possible', async () => {
    const res = await hikerAgent.post('/api/bookings').send({ tsID: lunch, n_people: 8 });
    expect(res.status).toBe(201);
    expect(seatsOf(ctx, res.body.booking.bID)).toEqual({ 1: 2, 4: 6 });
  });

  it('shares a table with another party', async () => {
    await hikerAgent.post('/api/bookings').send({ tsID: lunch, n_people: 3 }); // takes 3 of table 3
    const sara = await loginAs(ctx, 'sara@mail.it');
    const res = await sara.post('/api/bookings').send({ tsID: lunch, n_people: 1 });
    expect(seatsOf(ctx, res.body.booking.bID)).toEqual({ 3: 1 });
  });

  it('allows only one booking per hiker in the same slot', async () => {
    await hikerAgent.post('/api/bookings').send({ tsID: lunch, n_people: 2 });
    const res = await hikerAgent.post('/api/bookings').send({ tsID: lunch, n_people: 2 });
    expect(res.status).toBe(409);
  });

  it('refuses a party larger than the free seats and saves nothing', async () => {
    const res = await hikerAgent.post('/api/bookings').send({ tsID: lunch, n_people: 15 });
    expect(res.status).toBe(409);
    expect(ctx.db.prepare('SELECT COUNT(*) AS n FROM bookings').get().n).toBe(0);
  });

  it('closes bookings 2 hours before the slot', async () => {
    const soon = addSlot(ctx, '2026-12-01 09:30', '2026-12-01 10:30', { 1: 4 });
    const res = await hikerAgent.post('/api/bookings').send({ tsID: soon, n_people: 2 });
    expect(res.status).toBe(409);
    expect(res.body.error.message).toMatch(/two hours/);
  });

  it('returns 404 for an unknown slot', async () => {
    const res = await hikerAgent.post('/api/bookings').send({ tsID: 999, n_people: 2 });
    expect(res.status).toBe(404);
  });

  it('returns 400 when the party size is not a JSON number', async () => {
    const res = await hikerAgent.post('/api/bookings').send({ tsID: lunch, n_people: '2' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('requires login', async () => {
    const res = await request(ctx.app).post('/api/bookings').send({ tsID: lunch, n_people: 2 });
    expect(res.status).toBe(401);
  });

  it('is not available to employees', async () => {
    const employee = await loginAs(ctx, 'elena@hut.it');
    const res = await employee.post('/api/bookings').send({ tsID: lunch, n_people: 2 });
    expect(res.status).toBe(403);
  });
});

describe('GET /api/bookings', () => {
  it('lists only the bookings of the logged-in hiker', async () => {
    await hikerAgent.post('/api/bookings').send({ tsID: lunch, n_people: 2 });
    const sara = await loginAs(ctx, 'sara@mail.it');
    await sara.post('/api/bookings').send({ tsID: lunch, n_people: 2 });

    const res = await hikerAgent.get('/api/bookings');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].contact_name).toBe('Marco Bianchi');
  });
});
