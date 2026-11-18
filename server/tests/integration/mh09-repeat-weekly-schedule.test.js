// MH-09 Repeat a weekly schedule — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addEmployee, addSlot, loginAs } from '../helpers/app.js';

let ctx, elena, marco;

// NOW is Tuesday 1 Dec 2026, 08:00 Europe/Rome: weeks of 7 and 14 December are in the future
const SOURCE = '2026-12-07';
const TARGET = '2026-12-14';

const repeat = (body = { source_week: SOURCE, target_week: TARGET }, agent = elena) =>
  agent.post('/api/timeslots/repeat-week').send(body);

const slotsBetween = (from, to) => ctx.db.prepare(`
  SELECT tsID, start_time, end_time FROM timeslots
  WHERE start_time >= ? AND start_time < ? ORDER BY start_time`).all(from, to);
const targetSlots = () => slotsBetween('2026-12-14 00:00', '2026-12-21 00:00');
const sourceSlots = () => slotsBetween('2026-12-07 00:00', '2026-12-14 00:00');
const tablesOf = tsID => Object.fromEntries(ctx.db.prepare(
  'SELECT table_no, seats FROM slot_tables WHERE tsID = ? ORDER BY table_no').all(tsID)
  .map(t => [t.table_no, t.seats]));
const times = slots => slots.map(s => [s.start_time, s.end_time]);

beforeEach(async () => {
  freezeTime();
  ctx = createTestContext();
  addEmployee(ctx);
  addHiker(ctx);
  elena = await loginAs(ctx, 'elena@hut.it');
  marco = await loginAs(ctx, 'marco@mail.it');
  // source week: Monday lunch, Monday dinner, Sunday lunch
  addSlot(ctx, '2026-12-07 12:00', '2026-12-07 13:00', { 1: 4, 2: 6 });
  addSlot(ctx, '2026-12-07 19:00', '2026-12-07 20:30', { 1: 8 });
  addSlot(ctx, '2026-12-13 12:00', '2026-12-13 13:00', { 1: 2, 2: 2, 3: 2 });
});
afterEach(() => {
  vi.useRealTimers();
  ctx.db.close();
});

describe('POST /api/timeslots/repeat-week — empty target week', () => {
  it('copies all the slots of the week, on the same weekdays and times', async () => {
    const res = await repeat();
    expect(res.status).toBe(201);
    expect(res.body.slotIds).toHaveLength(3);
    expect(res.body.replacedCount).toBe(0);
    expect(times(targetSlots())).toEqual([
      ['2026-12-14 12:00', '2026-12-14 13:00'],
      ['2026-12-14 19:00', '2026-12-14 20:30'],
      ['2026-12-20 12:00', '2026-12-20 13:00'],
    ]);
  });

  it('copies the table layout of each slot', async () => {
    const { slotIds } = (await repeat()).body;
    expect(slotIds.map(tablesOf)).toEqual([{ 1: 4, 2: 6 }, { 1: 8 }, { 1: 2, 2: 2, 3: 2 }]);
  });

  it('leaves the source week unchanged', async () => {
    const before = sourceSlots();
    await repeat();
    expect(sourceSlots()).toEqual(before);
  });

  it('copies the layout but not the bookings: the new slots are completely free', async () => {
    const lunch = sourceSlots()[0].tsID;
    await marco.post('/api/bookings').send({ tsID: lunch, n_people: 6 });
    const { slotIds } = (await repeat()).body;

    const copy = await request(ctx.app).get(`/api/timeslots/${slotIds[0]}`);
    expect(copy.body).toMatchObject({ capacity: 10, free_seats: 10 });
  });

  it('the copied slots can be booked by hikers (MH-01)', async () => {
    const { slotIds } = (await repeat()).body;
    const res = await marco.post('/api/bookings').send({ tsID: slotIds[0], n_people: 4 });
    expect(res.status).toBe(201);
  });

  it('copies onto a week several weeks ahead, or onto an earlier week', async () => {
    expect((await repeat({ source_week: SOURCE, target_week: '2027-01-04' })).status).toBe(201);
    expect(times(slotsBetween('2027-01-04 00:00', '2027-01-11 00:00'))[0])
      .toEqual(['2027-01-04 12:00', '2027-01-04 13:00']);

    expect((await repeat({ source_week: '2027-01-04', target_week: TARGET })).status).toBe(201);
    expect(targetSlots()).toHaveLength(3);
  });
});

describe('POST /api/timeslots/repeat-week — target week with a schedule', () => {
  let oldLunch, oldDinner;

  beforeEach(() => {
    oldLunch = addSlot(ctx, '2026-12-15 11:00', '2026-12-15 12:00', { 1: 10 });
    oldDinner = addSlot(ctx, '2026-12-19 20:00', '2026-12-19 21:00', { 1: 10 });
    ctx.db.prepare('INSERT INTO slot_menus (tsID, menu) VALUES (?, ?)').run(oldLunch, 'Old menu');
  });

  it('without reservations, the existing schedule is completely replaced', async () => {
    const res = await repeat();
    expect(res.status).toBe(201);
    expect(res.body.replacedCount).toBe(2);
    expect(times(targetSlots())).toEqual([
      ['2026-12-14 12:00', '2026-12-14 13:00'],
      ['2026-12-14 19:00', '2026-12-14 20:30'],
      ['2026-12-20 12:00', '2026-12-20 13:00'],
    ]);
  });

  it('removes the old slots together with their tables and menus', async () => {
    const { slotIds } = (await repeat()).body;
    expect(times(targetSlots())).not.toContainEqual(['2026-12-15 11:00', '2026-12-15 12:00']);
    expect(times(targetSlots())).not.toContainEqual(['2026-12-19 20:00', '2026-12-19 21:00']);
    expect(ctx.db.prepare(
      'SELECT COUNT(*) AS n FROM slot_tables WHERE tsID NOT IN (SELECT tsID FROM timeslots)').get().n).toBe(0);
    expect(ctx.db.prepare("SELECT COUNT(*) AS n FROM slot_menus WHERE menu = 'Old menu'").get().n).toBe(0);
    expect(slotIds.map(tablesOf)).toEqual([{ 1: 4, 2: 6 }, { 1: 8 }, { 1: 2, 2: 2, 3: 2 }]);
  });

  it('with a reservation, the copy is refused (409) and nothing changes', async () => {
    await marco.post('/api/bookings').send({ tsID: oldDinner, n_people: 2 });
    const before = targetSlots();

    const res = await repeat();
    expect(res.status).toBe(409);
    expect(res.body.error.message).toBe('The target week has reservations: it cannot be replaced');
    expect(targetSlots()).toEqual(before);
    expect(tablesOf(oldLunch)).toEqual({ 1: 10 });
  });

  it('a reservation made by an employee also blocks the copy', async () => {
    await elena.post('/api/staff/bookings').send({
      hiker: { mode: 'temporary', name: 'Walk-in Guest' }, tsID: oldLunch, n_people: 2 });
    expect((await repeat()).status).toBe(409);
    expect(targetSlots()).toHaveLength(2);
  });

  it('a reservation in the source week does not block the copy', async () => {
    await marco.post('/api/bookings').send({ tsID: sourceSlots()[0].tsID, n_people: 2 });
    expect((await repeat()).status).toBe(201);
  });

  it('a reservation in the following week does not block the copy', async () => {
    const nextWeek = addSlot(ctx, '2026-12-21 12:00', '2026-12-21 13:00', { 1: 4 });
    await marco.post('/api/bookings').send({ tsID: nextWeek, n_people: 2 });
    expect((await repeat()).status).toBe(201);
    expect((await request(ctx.app).get(`/api/timeslots/${nextWeek}`)).status).toBe(200);
  });

  it('after the reservation is cancelled (MH-08), the week can be replaced', async () => {
    const booking = (await marco.post('/api/bookings').send({ tsID: oldDinner, n_people: 2 })).body.booking;
    expect((await repeat()).status).toBe(409);
    await marco.delete(`/api/bookings/${booking.bID}`);
    expect((await repeat()).status).toBe(201);
  });

  it('is all-or-nothing: if a copy fails, the old schedule stays as it was', async () => {
    ctx.db.exec(`CREATE TRIGGER fail_copy BEFORE INSERT ON slot_tables
      WHEN NEW.seats = 8 AND (SELECT start_time FROM timeslots WHERE tsID = NEW.tsID) >= '2026-12-14'
      BEGIN SELECT RAISE(ABORT, 'copy failed'); END`);
    const before = targetSlots();

    expect((await repeat()).status).not.toBe(201);
    expect(targetSlots()).toEqual(before);
    expect(tablesOf(oldLunch)).toEqual({ 1: 10 });
  });
});

describe('POST /api/timeslots/repeat-week — invalid requests', () => {
  it('refuses an empty source week (400) and leaves the target week unchanged', async () => {
    addSlot(ctx, '2026-12-15 11:00', '2026-12-15 12:00', { 1: 10 });
    const res = await repeat({ source_week: '2026-12-28', target_week: TARGET });
    expect(res.status).toBe(400);
    expect(res.body.error.message).toBe('Source week has no slots');
    expect(targetSlots()).toHaveLength(1);
  });

  it.each([
    ['the same week twice', { source_week: SOURCE, target_week: SOURCE }],
    ['a day that is not a Monday', { source_week: '2026-12-08', target_week: TARGET }],
    ['a wrong date format', { source_week: '07/12/2026', target_week: TARGET }],
    ['a missing week', { source_week: SOURCE }],
    ['an unknown field', { source_week: SOURCE, target_week: TARGET, overwrite: true }],
  ])('rejects %s with 400', async (_, body) => {
    const res = await repeat(body);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(targetSlots()).toEqual([]);
  });

  it('refuses a target week that has already started (slots would be in the past)', async () => {
    const res = await repeat({ source_week: SOURCE, target_week: '2026-11-30' });
    expect(res.status).toBe(400);
    expect(slotsBetween('2026-11-30 00:00', '2026-12-07 00:00')).toEqual([]);
  });

  it('refuses a slot whose duration would change with the clock change', async () => {
    addSlot(ctx, '2027-03-21 01:00', '2027-03-21 04:00', { 1: 4 });
    const res = await repeat({ source_week: '2027-03-15', target_week: '2027-03-22' });
    expect(res.status).toBe(400);
    expect(res.body.error.message).toBe('Clock change would alter slot duration');
    expect(slotsBetween('2027-03-22 00:00', '2027-03-29 00:00')).toEqual([]);
  });

  it('requires a login (401)', async () => {
    expect((await repeat(undefined, request(ctx.app))).status).toBe(401);
    expect(targetSlots()).toEqual([]);
  });

  it('is reserved to employees: a hiker gets 403', async () => {
    expect((await repeat(undefined, marco)).status).toBe(403);
    expect(targetSlots()).toEqual([]);
  });
});
