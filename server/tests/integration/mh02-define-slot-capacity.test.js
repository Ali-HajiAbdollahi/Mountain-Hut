// MH-02 Define slot capacity — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addEmployee, addSlot, loginAs } from '../helpers/app.js';

let ctx, employee;
const layout = [{ table_no: 1, seats: 2 }, { table_no: 2, seats: 4 }, { table_no: 3, seats: 6 }];

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addHiker(ctx);
  addEmployee(ctx);
  employee = await loginAs(ctx, 'elena@hut.it');
});
afterEach(() => {
  vi.useRealTimers();
});

describe('POST /api/timeslots', () => {
  it('lets an employee create a slot with its tables', async () => {
    const res = await employee.post('/api/timeslots')
      .send({ start_time: '2026-12-01 12:00', end_time: '2026-12-01 13:00', tables: layout });
    expect(res.status).toBe(201);
    expect(res.headers.location).toBe(`/api/timeslots/${res.body.tsID}`);
    expect(res.body).toMatchObject({ capacity: 12, free_seats: 12 });
    expect(res.body.tables).toHaveLength(3);
  });

  it('supports several slots for the same meal and a different layout at dinner', async () => {
    const first = await employee.post('/api/timeslots')
      .send({ start_time: '2026-12-01 12:00', end_time: '2026-12-01 13:00', tables: layout });
    const second = await employee.post('/api/timeslots')
      .send({ start_time: '2026-12-01 13:00', end_time: '2026-12-01 14:00', copy_from_tsID: first.body.tsID });
    const dinner = await employee.post('/api/timeslots')
      .send({ start_time: '2026-12-01 19:00', end_time: '2026-12-01 20:30', tables: [{ table_no: 1, seats: 8 }] });

    expect(second.status).toBe(201);
    expect(second.body.capacity).toBe(12);
    expect(dinner.body.capacity).toBe(8);
  });

  it('rejects a duplicate slot', async () => {
    const body = { start_time: '2026-12-01 12:00', end_time: '2026-12-01 13:00', tables: layout };
    await employee.post('/api/timeslots').send(body);
    expect((await employee.post('/api/timeslots').send(body)).status).toBe(409);
  });

  it('rejects slots in the past or with end before start', async () => {
    const past = await employee.post('/api/timeslots')
      .send({ start_time: '2026-11-30 12:00', end_time: '2026-11-30 13:00', tables: layout });
    const reversed = await employee.post('/api/timeslots')
      .send({ start_time: '2026-12-01 13:00', end_time: '2026-12-01 12:00', tables: layout });
    expect(past.status).toBe(400);
    expect(reversed.status).toBe(400);
  });

  it('does not save the slot when the layout is invalid', async () => {
    const res = await employee.post('/api/timeslots').send({
      start_time: '2026-12-01 12:00', end_time: '2026-12-01 13:00',
      tables: [{ table_no: 1, seats: 2 }, { table_no: 1, seats: 4 }] });
    expect(res.status).toBe(400);
    expect(ctx.db.prepare('SELECT COUNT(*) AS n FROM timeslots').get().n).toBe(0);
  });

  it('is reserved to employees', async () => {
    const body = { start_time: '2026-12-01 12:00', end_time: '2026-12-01 13:00', tables: layout };
    const hiker = await loginAs(ctx, 'marco@mail.it');
    expect((await hiker.post('/api/timeslots').send(body)).status).toBe(403);
    expect((await request(ctx.app).post('/api/timeslots').send(body)).status).toBe(401);
  });
});

describe('PUT /api/timeslots/:id/tables', () => {
  it('defines the tables of a slot that has none', async () => {
    const tsID = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', {});
    const res = await employee.put(`/api/timeslots/${tsID}/tables`).send({ tables: layout });
    expect(res.status).toBe(200);
    expect(res.body.capacity).toBe(12);
  });

  it('refuses to redefine a layout that already exists', async () => {
    const tsID = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 4 });
    expect((await employee.put(`/api/timeslots/${tsID}/tables`).send({ tables: layout })).status).toBe(409);
  });

  it('returns 404 for an unknown slot', async () => {
    expect((await employee.put('/api/timeslots/999/tables').send({ tables: layout })).status).toBe(404);
  });
});

describe('GET /api/timeslots', () => {
  it('is public and shows capacity and free seats of each slot of the day', async () => {
    const lunch = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 2, 2: 4 });
    addSlot(ctx, '2026-12-02 12:00', '2026-12-02 13:00', { 1: 2 });
    const hiker = await loginAs(ctx, 'marco@mail.it');
    await hiker.post('/api/bookings').send({ tsID: lunch, n_people: 3 });

    const res = await request(ctx.app).get('/api/timeslots?date=2026-12-01');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0]).toMatchObject({ tsID: lunch, capacity: 6, free_seats: 3 });
  });

  it('requires a valid date', async () => {
    expect((await request(ctx.app).get('/api/timeslots')).status).toBe(400);
    expect((await request(ctx.app).get('/api/timeslots?date=01-12-2026')).status).toBe(400);
  });

  it('returns one slot by id, or 404', async () => {
    const tsID = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 2 });
    expect((await request(ctx.app).get(`/api/timeslots/${tsID}`)).body.capacity).toBe(2);
    expect((await request(ctx.app).get('/api/timeslots/999')).status).toBe(404);
    expect((await request(ctx.app).get('/api/timeslots/abc')).status).toBe(400);
  });
});
