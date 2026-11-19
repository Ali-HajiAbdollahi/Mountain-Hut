// MH-11 View meal details — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addEmployee, addSlot, loginAs } from '../helpers/app.js';

let ctx, lunch, dinner, elena;

const publish = (tsID, menu) => elena.put(`/api/timeslots/${tsID}/menu`).send({ menu });
const day = date => request(ctx.app).get('/api/timeslots').query({ date });
const slot = tsID => request(ctx.app).get(`/api/timeslots/${tsID}`);

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addEmployee(ctx);
  lunch = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 4, 2: 2 });
  dinner = addSlot(ctx, '2026-12-01 19:00', '2026-12-01 20:30', { 1: 8 });
  elena = await loginAs(ctx, 'elena@hut.it');
});
afterEach(() => {
  vi.useRealTimers();
});

describe('GET /api/timeslots?date= (meal times and menus of a day)', () => {
  it('is public: a visitor without login sees meal times and menus', async () => {
    await publish(lunch, 'Polenta with mushrooms\nApple tart');
    const res = await day('2026-12-01');
    expect(res.status).toBe(200);
    expect(res.body.map(s => [s.start_time, s.end_time])).toEqual([
      ['2026-12-01 12:00', '2026-12-01 13:00'],
      ['2026-12-01 19:00', '2026-12-01 20:30'],
    ]);
    expect(res.body[0].menu).toBe('Polenta with mushrooms\nApple tart');
  });

  it('shows a different menu for lunch and dinner of the same day', async () => {
    await publish(lunch, 'Polenta');
    await publish(dinner, 'Venison stew');
    const res = await day('2026-12-01');
    expect(res.body.map(s => [s.tsID, s.menu])).toEqual([[lunch, 'Polenta'], [dinner, 'Venison stew']]);
  });

  it('returns menu null for a slot without a published menu', async () => {
    await publish(lunch, 'Polenta');
    const res = await day('2026-12-01');
    expect(res.body.find(s => s.tsID === dinner).menu).toBeNull();
  });

  it('keeps capacity, free seats and tables next to the menu', async () => {
    await publish(lunch, 'Polenta');
    const lunchSlot = (await day('2026-12-01')).body.find(s => s.tsID === lunch);
    expect(lunchSlot).toMatchObject({ capacity: 6, free_seats: 6, menu: 'Polenta' });
    expect(lunchSlot.tables).toHaveLength(2);
  });

  it('only returns the slots and menus of the requested date', async () => {
    const tomorrow = addSlot(ctx, '2026-12-02 12:00', '2026-12-02 13:00', { 1: 4 });
    await publish(tomorrow, 'Minestrone');
    const res = await day('2026-12-02');
    expect(res.body).toHaveLength(1);
    expect(res.body[0]).toMatchObject({ tsID: tomorrow, menu: 'Minestrone' });
  });

  it('returns an empty list for a day without meals', async () => {
    const res = await day('2026-12-25');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('requires a valid date', async () => {
    expect((await request(ctx.app).get('/api/timeslots')).status).toBe(400);
    expect((await day('01/12/2026')).status).toBe(400);
  });
});

describe('GET /api/timeslots/:id (details of one meal)', () => {
  it('is public and returns the meal time with its menu', async () => {
    await publish(dinner, 'Venison stew');
    const res = await slot(dinner);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      tsID: dinner,
      start_time: '2026-12-01 19:00',
      end_time: '2026-12-01 20:30',
      capacity: 8,
      menu: 'Venison stew',
    });
  });

  it('returns menu null when no menu has been published', async () => {
    expect((await slot(lunch)).body.menu).toBeNull();
  });

  it('keeps the formatting of the menu (bold, italic, nested lists)', async () => {
    const html = '<p><b>Lunch</b></p><ul><li>Canederli<ul><li><i>with butter</i></li></ul></li></ul>';
    await publish(lunch, html);
    expect((await slot(lunch)).body.menu).toBe(html);
    expect((await day('2026-12-01')).body[0].menu).toBe(html);
  });

  it('shows the latest menu after the employee changes it', async () => {
    await publish(lunch, 'Polenta');
    await publish(lunch, 'Risotto');
    expect((await slot(lunch)).body.menu).toBe('Risotto');
    expect((await day('2026-12-01')).body[0].menu).toBe('Risotto');
  });

  it('is visible to a logged-in hiker as well', async () => {
    addHiker(ctx);
    const marco = await loginAs(ctx, 'marco@mail.it');
    await publish(lunch, 'Polenta');
    expect((await marco.get(`/api/timeslots/${lunch}`)).body.menu).toBe('Polenta');
  });

  it('returns 404 for an unknown slot and 400 for an invalid id', async () => {
    expect((await slot(999)).status).toBe(404);
    expect((await slot('abc')).status).toBe(400);
    expect((await slot(0)).status).toBe(400);
  });
});
