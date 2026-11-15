// MH-11 View meal details — unit tests (no database, fake DAO)
import { describe, it, expect } from 'vitest';
import { createSlotService } from '../../services/slotService.js';
import { NotFoundError, ValidationError } from '../../errors.js';

const lunch = { tsID: 1, start_time: '2026-12-01 12:00', end_time: '2026-12-01 13:00' };
const dinner = { tsID: 2, start_time: '2026-12-01 19:00', end_time: '2026-12-01 20:30' };
const nextDay = { tsID: 3, start_time: '2026-12-02 12:00', end_time: '2026-12-02 13:00' };

// slots and menus as stored in the database; menus = { tsID: text }
function fakeDao(menus = {}) {
  const slots = new Map([lunch, dinner, nextDay].map(s => [s.tsID, s]));
  const tables = { 1: [{ table_no: 1, seats: 4, free_seats: 3 }, { table_no: 2, seats: 2, free_seats: 2 }] };
  return {
    find: id => slots.get(id),
    tables: id => tables[id] ?? [],
    menu: id => menus[id] ?? null,
    list: date => [...slots.values()]
      .filter(s => s.start_time.startsWith(date))
      .map(s => ({ tsID: s.tsID, menu: menus[s.tsID] ?? null })),
  };
}

describe('slotService.detailsWithMenu (GET /api/timeslots/:id)', () => {
  it('returns the meal time together with the menu of the slot', () => {
    const service = createSlotService(fakeDao({ 1: 'Polenta with mushrooms\nApple tart' }));
    expect(service.detailsWithMenu(1)).toMatchObject({
      tsID: 1,
      start_time: '2026-12-01 12:00',
      end_time: '2026-12-01 13:00',
      menu: 'Polenta with mushrooms\nApple tart',
    });
  });

  it('keeps the capacity and free seats of the slot', () => {
    const slot = createSlotService(fakeDao({ 1: 'Soup' })).detailsWithMenu(1);
    expect(slot).toMatchObject({ capacity: 6, free_seats: 5 });
    expect(slot.tables).toHaveLength(2);
  });

  it('returns menu null when no menu has been published', () => {
    expect(createSlotService(fakeDao()).detailsWithMenu(2).menu).toBeNull();
  });

  it('returns the formatted menu (HTML) exactly as it was saved', () => {
    const html = '<p><b>Lunch</b></p><ul><li>Canederli<ul><li><i>with butter</i></li></ul></li></ul>';
    expect(createSlotService(fakeDao({ 1: html })).detailsWithMenu(1).menu).toBe(html);
  });

  it('throws NotFoundError for an unknown slot', () => {
    expect(() => createSlotService(fakeDao()).detailsWithMenu(42)).toThrow(NotFoundError);
  });
});

describe('slotService.list (GET /api/timeslots?date=)', () => {
  it('gives each slot of the day its own menu', () => {
    const service = createSlotService(fakeDao({ 1: 'Polenta', 2: 'Venison stew' }));
    const slots = service.list('2026-12-01');
    expect(slots.map(s => [s.tsID, s.menu])).toEqual([[1, 'Polenta'], [2, 'Venison stew']]);
  });

  it('shows menu null for the slots without a menu', () => {
    const slots = createSlotService(fakeDao({ 1: 'Polenta' })).list('2026-12-01');
    expect(slots.find(s => s.tsID === 2).menu).toBeNull();
  });

  it('only returns the slots of the requested date', () => {
    const slots = createSlotService(fakeDao({ 3: 'Minestrone' })).list('2026-12-02');
    expect(slots).toHaveLength(1);
    expect(slots[0]).toMatchObject({ tsID: 3, start_time: '2026-12-02 12:00', menu: 'Minestrone' });
  });

  it('returns an empty list for a day without slots', () => {
    expect(createSlotService(fakeDao()).list('2026-12-25')).toEqual([]);
  });

  it.each([undefined, '2026-12-1', '01/12/2026', '2026-13-01'])('rejects the date %s', date => {
    expect(() => createSlotService(fakeDao()).list(date)).toThrow(ValidationError);
  });
});
