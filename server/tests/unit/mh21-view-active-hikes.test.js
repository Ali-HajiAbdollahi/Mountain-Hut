// MH-21 View active hikes — unit tests (service with fake DAO)
import { describe, it, expect, vi, afterEach } from 'vitest';
import { createHikeService } from '../../services/hikeService.js';
import { ForbiddenError } from '../../errors.js';

const elena = { uID: 1, role: 'employee' };

function fakeDao(rows = []) {
  return { listActive: vi.fn(() => rows) };
}

afterEach(() => {
  vi.useRealTimers();
});

function at(isoUtc) {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date(isoUtc));
}

describe('hikeService.listActive', () => {
  it('asks the DAO for the hikes active now, in hut local time (winter, UTC+1)', () => {
    at('2026-12-01T08:30:00Z');
    const dao = fakeDao();
    createHikeService(dao).listActive(elena);
    expect(dao.listActive).toHaveBeenCalledWith('2026-12-01 09:30');
  });

  it('uses the hut local time in summer as well (UTC+2)', () => {
    at('2026-07-15T06:05:00Z');
    const dao = fakeDao();
    createHikeService(dao).listActive(elena);
    expect(dao.listActive).toHaveBeenCalledWith('2026-07-15 08:05');
  });

  it('uses the local date when UTC is still on the previous day', () => {
    at('2026-12-31T23:30:00Z');
    const dao = fakeDao();
    createHikeService(dao).listActive(elena);
    expect(dao.listActive).toHaveBeenCalledWith('2027-01-01 00:30');
  });

  it('returns the hikes found by the DAO unchanged', () => {
    const rows = [{
      hID: 3,
      hiker_name: 'Marco Bianchi',
      destination: 'Chiaretto Lake',
      route: 'East ridge',
      expected_return: '2026-12-01 17:00',
      waypoints: [{ position: 1, name: 'Vizo Mozzo' }],
    }];
    expect(createHikeService(fakeDao(rows)).listActive(elena)).toEqual(rows);
  });

  it('returns an empty list when nobody is out', () => {
    expect(createHikeService(fakeDao()).listActive(elena)).toEqual([]);
  });

  it.each([
    ['a hiker', { uID: 7, role: 'hiker' }],
    ['nobody', undefined],
  ])('is reserved to employees: %s gets ForbiddenError', (_, user) => {
    const dao = fakeDao();
    expect(() => createHikeService(dao).listActive(user)).toThrow(ForbiddenError);
    expect(dao.listActive).not.toHaveBeenCalled();
  });
});
