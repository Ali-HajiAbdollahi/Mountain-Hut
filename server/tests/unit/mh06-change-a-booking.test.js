// MH-06 Change a booking — unit tests (no database, fake DAOs)
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createBookingChangeService } from '../../services/bookingChangeService.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../errors.js';

const hiker = { uID: 7, role: 'hiker' };
const NOW = new Date('2026-12-01T07:00:00Z');

const current = {
  bID: 10,
  uID: 7,
  tsID: 1,
  n_people: 2,
  start_time: '2026-12-10 12:00', // meal more than 48 hours after NOW
  created_at: '2026-11-30 07:00:00', // 24 hours before NOW (UTC, as SQLite stores it)
  requirements: [{ rID: 1, n_people: 1, description: 'vegan', allergy: false }],
};

function setup({ booking = current, duplicate, slot = { tsID: 2, start_time: '2026-12-10 13:00' }, freeSeats = 6 } = {}) {
  const bookings = {
    atomic: action => action(),
    find: vi.fn(() => booking),
    duplicate: vi.fn(() => duplicate),
    removeAssignments: vi.fn(),
    update: vi.fn(),
    assign: vi.fn(),
    replaceRequirements: vi.fn(),
  };
  const slots = {
    find: vi.fn(() => slot),
    tables: vi.fn(() => [{ table_no: 1, seats: freeSeats, free_seats: freeSeats }]),
  };
  return { bookings, slots, service: createBookingChangeService(bookings, slots) };
}

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(NOW);
});
afterEach(() => {
  vi.useRealTimers();
});

describe('bookingChangeService.update — who and what can change', () => {
  it('only accepts hikers', () => {
    const { service } = setup();
    expect(() => service.update(10, { n_people: 3 }, { uID: 7, role: 'employee' })).toThrow(ForbiddenError);
  });

  it('hides bookings of other hikers', () => {
    const { service } = setup();
    expect(() => service.update(10, { n_people: 3 }, { uID: 8, role: 'hiker' })).toThrow(NotFoundError);
  });

  it('fails for a booking that does not exist', () => {
    const { service } = setup({ booking: null });
    expect(() => service.update(10, { n_people: 3 }, hiker)).toThrow(NotFoundError);
  });

  it('requires at least one field and no unknown fields', () => {
    const { service } = setup();
    expect(() => service.update(10, {}, hiker)).toThrow(ValidationError);
    expect(() => service.update(10, { contact_name: 'x' }, hiker)).toThrow(ValidationError);
  });

  // [BUG] MH-06 rule (confirmed by the team): a booking can be changed until 48 hours
  // before the booked meal (slot start_time). bookingChangeService instead counts 48 hours
  // from created_at, i.e. from when the booking was made. Fails until fixed.
  it('[BUG] allows changes up to exactly 48 hours before the meal, however old the booking is', () => {
    // NOW is 1 Dec 08:00 Europe/Rome; the meal is 3 Dec 08:00
    const { service } = setup({
      booking: { ...current, start_time: '2026-12-03 08:00', created_at: '2026-11-01 10:00:00' } });
    expect(() => service.update(10, { n_people: 3 }, hiker)).not.toThrow();
  });

  it('[BUG] refuses changes less than 48 hours before the meal, even for a new booking', () => {
    const { bookings, service } = setup({
      booking: { ...current, start_time: '2026-12-03 07:59', created_at: '2026-12-01 06:00:00' } });
    expect(() => service.update(10, { n_people: 3 }, hiker)).toThrow(ConflictError);
    expect(bookings.update).not.toHaveBeenCalled();
  });
});

describe('bookingChangeService.update — seats and requirements', () => {
  it('changing the party size frees the old seats and allocates new ones', () => {
    const { bookings, service } = setup();
    service.update(10, { n_people: 4 }, hiker);
    expect(bookings.removeAssignments).toHaveBeenCalledWith(10);
    expect(bookings.update).toHaveBeenCalledWith(10, { tsID: 1, n_people: 4 });
    expect(bookings.assign).toHaveBeenCalledWith(10, 1, [{ table_no: 1, seats: 4 }]);
  });

  it('moving to another slot allocates seats in the new slot', () => {
    const { bookings, slots, service } = setup();
    service.update(10, { tsID: 2 }, hiker);
    expect(slots.tables).toHaveBeenCalledWith(2);
    expect(bookings.update).toHaveBeenCalledWith(10, { tsID: 2, n_people: 2 });
  });

  it('fails when the new party does not fit (availability is verified)', () => {
    const { service } = setup({ freeSeats: 3 });
    expect(() => service.update(10, { n_people: 4 }, hiker)).toThrow(ConflictError);
  });

  it('fails when the new slot does not exist', () => {
    const { service } = setup({ slot: null });
    expect(() => service.update(10, { tsID: 99 }, hiker)).toThrow(NotFoundError);
  });

  // [BUG] Team decision: the destination slot must respect the 2-hour booking window
  // of MH-01, like a new booking. Fails until fixed.
  it('[BUG] refuses to move into a slot that starts in less than 2 hours', () => {
    // NOW is 1 Dec 08:00 Europe/Rome
    const { bookings, service } = setup({ slot: { tsID: 2, start_time: '2026-12-01 09:59' } });
    expect(() => service.update(10, { tsID: 2 }, hiker)).toThrow(ConflictError);
    expect(bookings.update).not.toHaveBeenCalled();
  });

  it('moves into a slot that starts in exactly 2 hours', () => {
    const { service } = setup({ slot: { tsID: 2, start_time: '2026-12-01 10:00' } });
    expect(() => service.update(10, { tsID: 2 }, hiker)).not.toThrow();
  });

  it('refuses to move into a slot where the hiker already has another booking', () => {
    const { service } = setup({ duplicate: { bID: 11 } });
    expect(() => service.update(10, { tsID: 2 }, hiker)).toThrow(ConflictError);
  });

  it('changing only the requirements does not touch the tables', () => {
    const { bookings, service } = setup();
    const requirements = [{ description: 'shellfish', allergy: true, n_people: 1 }];
    service.update(10, { requirements }, hiker);
    expect(bookings.replaceRequirements).toHaveBeenCalledWith(10, requirements);
    expect(bookings.removeAssignments).not.toHaveBeenCalled();
  });

  it('keeps the existing requirements when they are not sent', () => {
    const { bookings, service } = setup();
    service.update(10, { n_people: 3 }, hiker);
    expect(bookings.replaceRequirements).not.toHaveBeenCalled();
  });

  it('rejects a smaller party when an existing requirement no longer fits', () => {
    const { service } = setup({
      booking: { ...current, n_people: 4, requirements: [{ n_people: 3, description: 'vegan', allergy: false }] },
    });
    expect(() => service.update(10, { n_people: 2 }, hiker)).toThrow(/exceeds party size/);
  });
});
