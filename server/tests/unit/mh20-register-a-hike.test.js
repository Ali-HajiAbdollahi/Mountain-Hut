// MH-20 Register a hike — unit tests (input validation + service with fake DAO)
import { describe, it, expect, vi } from 'vitest';
import { hikeInput } from '../../domain/hikeInput.js';
import { createHikeService } from '../../services/hikeService.js';
import { ForbiddenError, ValidationError } from '../../errors.js';

// 1 Dec 2026, 08:00 Europe/Rome
const NOW = new Date('2026-12-01T07:00:00Z').getTime();

const valid = {
  destination: 'Chiaretto Lake',
  route: 'Via the east ridge',
  departure_time: '2026-12-01 09:00',
  expected_return: '2026-12-01 17:30',
};

describe('hikeInput', () => {
  it('accepts a complete hike and trims the texts', () => {
    expect(hikeInput({
      ...valid,
      destination: '  Chiaretto Lake ',
      route: ' Via the east ridge ',
      waypoints: [{ name: ' Vizo Mozzo ' }],
    }, NOW)).toEqual({ ...valid, waypoints: [{ name: 'Vizo Mozzo' }] });
  });

  it('waypoints are optional and keep the order given', () => {
    expect(hikeInput(valid, NOW).waypoints).toEqual([]);
    expect(hikeInput({ ...valid, waypoints: [{ name: 'B' }, { name: 'A' }, { name: 'C' }] }, NOW)
      .waypoints.map(w => w.name)).toEqual(['B', 'A', 'C']);
  });

  it.each(['destination', 'route'])('requires a non-empty %s', field => {
    expect(() => hikeInput({ ...valid, [field]: undefined }, NOW)).toThrow(`${field} is required`);
    expect(() => hikeInput({ ...valid, [field]: '   ' }, NOW)).toThrow(ValidationError);
    expect(() => hikeInput({ ...valid, [field]: 42 }, NOW)).toThrow(ValidationError);
  });

  it.each(['departure_time', 'expected_return'])('requires %s in the YYYY-MM-DD HH:mm format', field => {
    expect(() => hikeInput({ ...valid, [field]: undefined }, NOW)).toThrow(ValidationError);
    expect(() => hikeInput({ ...valid, [field]: '2026-12-01T09:00' }, NOW)).toThrow(ValidationError);
    expect(() => hikeInput({ ...valid, [field]: '2026-02-30 09:00' }, NOW)).toThrow(ValidationError);
  });

  it('refuses a departure in the past, but accepts one starting right now', () => {
    expect(() => hikeInput({ ...valid, departure_time: '2026-12-01 07:59' }, NOW))
      .toThrow('departure_time cannot be in the past');
    expect(hikeInput({ ...valid, departure_time: '2026-12-01 08:00' }, NOW).departure_time)
      .toBe('2026-12-01 08:00');
  });

  it('requires the expected return to be after the departure', () => {
    expect(() => hikeInput({ ...valid, expected_return: '2026-12-01 09:00' }, NOW))
      .toThrow('expected_return must be after departure_time');
    expect(() => hikeInput({ ...valid, expected_return: '2026-12-01 08:30' }, NOW))
      .toThrow(ValidationError);
  });

  it('allows a return on a following day', () => {
    expect(hikeInput({ ...valid, expected_return: '2026-12-02 11:00' }, NOW).expected_return)
      .toBe('2026-12-02 11:00');
  });

  it('rejects unknown fields, including the owner uID', () => {
    expect(() => hikeInput({ ...valid, uID: 7 }, NOW)).toThrow('Unexpected field');
    expect(() => hikeInput({ ...valid, returned_at: '2026-12-01 18:00' }, NOW)).toThrow(ValidationError);
  });

  it('rejects invalid waypoints', () => {
    expect(() => hikeInput({ ...valid, waypoints: 'Vizo Mozzo' }, NOW)).toThrow('waypoints must be an array');
    expect(() => hikeInput({ ...valid, waypoints: [{ name: '' }] }, NOW)).toThrow('waypoint name is required');
    expect(() => hikeInput({ ...valid, waypoints: ['Vizo Mozzo'] }, NOW)).toThrow(ValidationError);
    expect(() => hikeInput({ ...valid, waypoints: [{ name: 'A', altitude: 2000 }] }, NOW)).toThrow(ValidationError);
  });

  it('rejects a body that is not an object', () => {
    expect(() => hikeInput(null, NOW)).toThrow(ValidationError);
    expect(() => hikeInput([valid], NOW)).toThrow(ValidationError);
  });
});

describe('hikeService.create', () => {
  const marco = { uID: 7, role: 'hiker' };

  function fakeDao() {
    const dao = {
      atomic: vi.fn(action => action()),
      insert: vi.fn(() => 1),
      addWaypoints: vi.fn(),
      find: vi.fn(hID => ({ hID, uID: 7 })),
    };
    return dao;
  }

  function withFrozenClock(test) {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(NOW);
    try { test(); } finally { vi.useRealTimers(); }
  }

  it('saves the hike for the logged-in hiker and returns it', () => withFrozenClock(() => {
    const dao = fakeDao();
    const hike = createHikeService(dao).create({ ...valid, waypoints: [{ name: 'Vizo Mozzo' }] }, marco);

    expect(dao.insert).toHaveBeenCalledWith({ uID: 7, ...valid });
    expect(dao.addWaypoints).toHaveBeenCalledWith(1, [{ name: 'Vizo Mozzo' }]);
    expect(dao.find).toHaveBeenCalledWith(1);
    expect(hike).toEqual({ hID: 1, uID: 7 });
  }));

  it('saves the hike and its waypoints in one transaction', () => withFrozenClock(() => {
    const dao = fakeDao();
    const order = [];
    dao.atomic.mockImplementation(action => { order.push('begin'); const r = action(); order.push('commit'); return r; });
    dao.insert.mockImplementation(() => { order.push('insert'); return 1; });
    dao.addWaypoints.mockImplementation(() => order.push('waypoints'));

    createHikeService(dao).create(valid, marco);
    expect(order).toEqual(['begin', 'insert', 'waypoints', 'commit']);
  }));

  it('propagates a failing waypoint insert, so the transaction is rolled back', () => withFrozenClock(() => {
    const dao = fakeDao();
    dao.addWaypoints.mockImplementation(() => { throw new Error('insert failed'); });
    expect(() => createHikeService(dao).create(valid, marco)).toThrow('insert failed');
    expect(dao.find).not.toHaveBeenCalled();
  }));

  it('does not touch the database when the input is invalid', () => withFrozenClock(() => {
    const dao = fakeDao();
    expect(() => createHikeService(dao).create({ ...valid, route: '' }, marco)).toThrow(ValidationError);
    expect(dao.atomic).not.toHaveBeenCalled();
  }));

  it.each([
    ['an employee', { uID: 1, role: 'employee' }],
    ['nobody', undefined],
  ])('is reserved to hikers: %s gets ForbiddenError', (_, user) => {
    const dao = fakeDao();
    expect(() => createHikeService(dao).create(valid, user)).toThrow(ForbiddenError);
    expect(dao.insert).not.toHaveBeenCalled();
  });
});
