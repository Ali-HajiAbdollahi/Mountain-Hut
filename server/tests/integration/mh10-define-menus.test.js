// MH-10 Define menus — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addEmployee, addSlot, loginAs } from '../helpers/app.js';

let ctx, elena, marco, lunch, dinner;

const formatted = '<strong>Lunch</strong><br>• Soup<br>  • <em>with croutons</em><br>• Apple tart';

const publish = (tsID, menu, agent = elena) => agent.put(`/api/timeslots/${tsID}/menu`).send({ menu });
const recent = (before, agent = elena) => agent.get('/api/timeslots/menus/recent').query({ before });
const menuRows = () => ctx.db.prepare('SELECT tsID, menu FROM slot_menus ORDER BY tsID').all();

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addEmployee(ctx);
  addHiker(ctx);
  elena = await loginAs(ctx, 'elena@hut.it');
  marco = await loginAs(ctx, 'marco@mail.it');
  lunch = addSlot(ctx, '2026-12-05 12:00', '2026-12-05 13:00', { 1: 4 });
  dinner = addSlot(ctx, '2026-12-05 19:00', '2026-12-05 20:00', { 1: 4 });
});
afterEach(() => {
  vi.useRealTimers();
  ctx.db.close();
});

describe('PUT /api/timeslots/:id/menu', () => {
  it('lets an employee define the menu of a slot as free text', async () => {
    const res = await publish(lunch, 'Polenta with mushrooms');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ tsID: lunch, menu: 'Polenta with mushrooms' });
    expect((await request(ctx.app).get(`/api/timeslots/${lunch}`)).body.menu).toBe('Polenta with mushrooms');
  });

  it('keeps the basic formatting: bold, italic, item list and sub-items', async () => {
    expect((await publish(lunch, formatted)).body.menu).toBe(formatted);
    expect(menuRows()).toEqual([{ tsID: lunch, menu: formatted }]);
  });

  it('removes the spaces around the text', async () => {
    expect((await publish(lunch, '  Barley soup \n')).body.menu).toBe('Barley soup');
  });

  it('a new menu replaces the previous one of the same slot', async () => {
    await publish(lunch, 'Polenta');
    const res = await publish(lunch, 'Risotto');
    expect(res.status).toBe(200);
    expect(menuRows()).toEqual([{ tsID: lunch, menu: 'Risotto' }]);
  });

  it('each slot has its own menu', async () => {
    await publish(lunch, 'Polenta');
    await publish(dinner, 'Venison stew');
    expect(menuRows()).toEqual([{ tsID: lunch, menu: 'Polenta' }, { tsID: dinner, menu: 'Venison stew' }]);
  });

  it.each([
    ['an empty menu', { menu: '' }],
    ['a menu of only spaces', { menu: '   ' }],
    ['a menu that is not text', { menu: 42 }],
    ['a missing menu', {}],
    ['an unknown field', { menu: 'Soup', price: 20 }],
  ])('rejects %s with 400 and saves nothing', async (_, body) => {
    const res = await elena.put(`/api/timeslots/${lunch}/menu`).send(body);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(menuRows()).toEqual([]);
  });

  it('an invalid menu does not delete the existing one', async () => {
    await publish(lunch, 'Polenta');
    expect((await publish(lunch, '  ')).status).toBe(400);
    expect(menuRows()).toEqual([{ tsID: lunch, menu: 'Polenta' }]);
  });

  it('returns 404 for an unknown slot and 400 for an invalid id', async () => {
    expect((await publish(999, 'Soup')).status).toBe(404);
    expect((await publish('abc', 'Soup')).status).toBe(400);
    expect(menuRows()).toEqual([]);
  });

  it('requires a login (401)', async () => {
    expect((await publish(lunch, 'Soup', request(ctx.app))).status).toBe(401);
    expect(menuRows()).toEqual([]);
  });

  it('is reserved to employees: a hiker gets 403', async () => {
    expect((await publish(lunch, 'Soup', marco)).status).toBe(403);
    expect(menuRows()).toEqual([]);
  });
});

describe('GET /api/timeslots/menus/recent (reuse previous menus)', () => {
  it('lists the menus of previous days, most recent first, with the slot they come from', async () => {
    const twoDaysBefore = addSlot(ctx, '2026-12-03 12:00', '2026-12-03 13:00', { 1: 4 });
    const dayBefore = addSlot(ctx, '2026-12-04 19:00', '2026-12-04 20:00', { 1: 4 });
    await publish(twoDaysBefore, 'Polenta');
    await publish(dayBefore, 'Venison stew');

    const res = await recent('2026-12-05 12:00');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([
      { tsID: dayBefore, start_time: '2026-12-04 19:00', end_time: '2026-12-04 20:00', menu: 'Venison stew' },
      { tsID: twoDaysBefore, start_time: '2026-12-03 12:00', end_time: '2026-12-03 13:00', menu: 'Polenta' },
    ]);
  });

  it('includes earlier slots of the same day and menus of past weeks', async () => {
    const lastWeek = addSlot(ctx, '2026-11-28 12:00', '2026-11-28 13:00', { 1: 4 });
    ctx.db.prepare('INSERT INTO slot_menus (tsID, menu) VALUES (?, ?)').run(lastWeek, 'Canederli');
    await publish(lunch, 'Polenta');

    expect((await recent('2026-12-05 19:00')).body.map(m => m.menu)).toEqual(['Polenta', 'Canederli']);
  });

  it('only lists slots that start before the reference time', async () => {
    await publish(lunch, 'Polenta');
    await publish(dinner, 'Venison stew');

    expect((await recent('2026-12-05 12:00')).body).toEqual([]);
    expect((await recent('2026-12-05 12:01')).body.map(m => m.menu)).toEqual(['Polenta']);
  });

  it('shows a menu used several times only once, from its most recent slot', async () => {
    const earlier = addSlot(ctx, '2026-12-03 12:00', '2026-12-03 13:00', { 1: 4 });
    await publish(earlier, 'Polenta');
    await publish(lunch, 'Polenta');
    await publish(dinner, 'Venison stew');

    const res = await recent('2026-12-06 00:00');
    expect(res.body.map(m => [m.tsID, m.menu])).toEqual([[dinner, 'Venison stew'], [lunch, 'Polenta']]);
  });

  it('returns at most the 20 most recent menus', async () => {
    for (let day = 1; day <= 25; day++) {
      const tsID = addSlot(ctx, `2027-01-${String(day).padStart(2, '0')} 12:00`,
        `2027-01-${String(day).padStart(2, '0')} 13:00`, { 1: 4 });
      await publish(tsID, `Menu of day ${day}`);
    }

    const res = await recent('2027-02-01 00:00');
    expect(res.body).toHaveLength(20);
    expect(res.body[0].menu).toBe('Menu of day 25');
    expect(res.body[19].menu).toBe('Menu of day 6');
  });

  it('does not list slots without a menu, and returns [] when there are none', async () => {
    expect((await recent('2026-12-06 00:00')).body).toEqual([]);
  });

  it('a reused menu can be changed without changing the original one', async () => {
    const yesterday = addSlot(ctx, '2026-12-04 12:00', '2026-12-04 13:00', { 1: 4 });
    await publish(yesterday, formatted);

    const [previous] = (await recent('2026-12-05 12:00')).body;
    await publish(lunch, previous.menu.replace('Apple tart', 'Strudel'));

    expect((await request(ctx.app).get(`/api/timeslots/${lunch}`)).body.menu)
      .toBe(formatted.replace('Apple tart', 'Strudel'));
    expect((await request(ctx.app).get(`/api/timeslots/${yesterday}`)).body.menu).toBe(formatted);
  });

  it.each([undefined, '2026-12-05', '2026-12-05T12:00', 'yesterday'])(
    'rejects the reference time %s with 400', async before => {
      expect((await recent(before)).status).toBe(400);
    });

  it('requires a login (401)', async () => {
    expect((await recent('2026-12-06 00:00', request(ctx.app))).status).toBe(401);
  });

  it('is reserved to employees: a hiker gets 403', async () => {
    expect((await recent('2026-12-06 00:00', marco)).status).toBe(403);
  });
});
