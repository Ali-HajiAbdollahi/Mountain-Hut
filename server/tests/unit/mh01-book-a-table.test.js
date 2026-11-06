// MH-01 Book a table — unit tests (no database, fake DAOs)
import { describe, it, expect, vi } from 'vitest';
import { allocateTables } from '../../domain/allocateTables.js';
import { requireBookingWindow } from '../../domain/time.js';
import { createBookingService } from '../../services/bookingService.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../errors.js';

const table = (table_no, free_seats) => ({ table_no, seats: free_seats, free_seats });

describe('allocateTables', () => {
  it('seats the whole party at one table when one is big enough', () => {
    expect(allocateTables([table(1, 2), table(2, 4), table(3, 6)], 4))
      .toEqual([{ table_no: 2, seats: 4 }]);
  });

  it('picks the single table with the fewest free seats that still fits', () => {
    expect(allocateTables([table(1, 8), table(2, 5), table(3, 6)], 5))
      .toEqual([{ table_no: 2, seats: 5 }]);
  });

  it('shares a partially occupied table with another party', () => {
    const rows = [{ table_no: 1, seats: 6, free_seats: 3 }];
    expect(allocateTables(rows, 3)).toEqual([{ table_no: 1, seats: 3 }]);
  });

  it('splits the party only when no single table fits, using as few tables as possible', () => {
    // 2+2+2+2 would need 4 tables; 6+2 needs only 2
    const result = allocateTables([table(1, 2), table(2, 2), table(3, 2), table(4, 6)], 8);
    expect(result).toHaveLength(2);
    expect(result.reduce((n, t) => n + t.seats, 0)).toBe(8);
  });

  it('with the same number of tables, uses the smallest set of free seats', () => {
    // party of 7: 4+4 (8 seats) is better than 4+6 (10 seats)
    const result = allocateTables([table(1, 4), table(2, 4), table(3, 6)], 7);
    expect(result.map(t => t.table_no).sort()).toEqual([1, 2]);
  });

  it('ignores tables without free seats', () => {
    expect(allocateTables([table(1, 0), table(2, 2)], 2)).toEqual([{ table_no: 2, seats: 2 }]);
  });

  it('throws a conflict when there are not enough free seats', () => {
    expect(() => allocateTables([table(1, 2), table(2, 2)], 5)).toThrow(ConflictError);
  });

  it('rejects a party size that is not a positive integer', () => {
    expect(() => allocateTables([table(1, 4)], 0)).toThrow(ValidationError);
    expect(() => allocateTables([table(1, 4)], 1.5)).toThrow(ValidationError);
  });
});

describe('requireBookingWindow', () => {
  // 1 Dec 2026, 10:00 in Europe/Rome
  const now = Date.parse('2026-12-01T09:00:00Z');

  it('accepts a slot starting exactly 2 hours later', () => {
    expect(() => requireBookingWindow('2026-12-01 12:00', now)).not.toThrow();
  });

  it('rejects a slot starting less than 2 hours later', () => {
    expect(() => requireBookingWindow('2026-12-01 11:59', now)).toThrow(ConflictError);
  });

  it('rejects a slot in the past', () => {
    expect(() => requireBookingWindow('2026-11-30 12:00', now)).toThrow(ConflictError);
  });
});

describe('bookingService.create', () => {
  const hiker = { uID: 7, name: 'Marco', phone: '333', role: 'hiker' };
  const futureSlot = { tsID: 1, start_time: '2099-01-01 12:00', end_time: '2099-01-01 13:00' };

  function setup({ slot = futureSlot, duplicate = undefined, tables = [table(1, 4), table(2, 6)] } = {}) {
    const bookings = {
      atomic: action => action(),
      duplicate: vi.fn(() => duplicate),
      insert: vi.fn(() => 99),
      assign: vi.fn(),
      addRequirements: vi.fn(),
      find: vi.fn(bID => ({ bID })),
    };
    const slots = { find: vi.fn(() => slot), tables: vi.fn(() => tables) };
    return { bookings, slots, service: createBookingService(bookings, slots) };
  }

  it('creates the booking with the hiker contact data and the allocated tables', () => {
    const { bookings, service } = setup();
    expect(service.create({ tsID: 1, n_people: 4 }, hiker)).toEqual({ bID: 99 });
    expect(bookings.insert).toHaveBeenCalledWith(
      { tsID: 1, uID: 7, contact_name: 'Marco', contact_phone: '333', n_people: 4 });
    expect(bookings.assign).toHaveBeenCalledWith(99, 1, [{ table_no: 1, seats: 4 }]);
  });

  it('only accepts hikers', () => {
    const { service } = setup();
    expect(() => service.create({ tsID: 1, n_people: 2 }, { ...hiker, role: 'employee' }))
      .toThrow(ForbiddenError);
  });

  it('requires tsID and n_people as positive integers', () => {
    const { service } = setup();
    expect(() => service.create({ n_people: 2 }, hiker)).toThrow(ValidationError);
    expect(() => service.create({ tsID: 1, n_people: '2' }, hiker)).toThrow(ValidationError);
    expect(() => service.create({ tsID: 1, n_people: 0 }, hiker)).toThrow(ValidationError);
  });

  it('rejects unknown fields', () => {
    const { service } = setup();
    expect(() => service.create({ tsID: 1, n_people: 2, private: true }, hiker)).toThrow(ValidationError);
  });

  it('fails when the slot does not exist', () => {
    const { service } = setup({ slot: null });
    expect(() => service.create({ tsID: 1, n_people: 2 }, hiker)).toThrow(NotFoundError);
  });

  it('allows only one booking per hiker in the same slot', () => {
    const { bookings, service } = setup({ duplicate: { bID: 5 } });
    expect(() => service.create({ tsID: 1, n_people: 2 }, hiker)).toThrow(ConflictError);
    expect(bookings.insert).not.toHaveBeenCalled();
  });

  it('fails when the slot is full', () => {
    const { bookings, service } = setup({ tables: [table(1, 2)] });
    expect(() => service.create({ tsID: 1, n_people: 3 }, hiker)).toThrow(ConflictError);
    expect(bookings.insert).not.toHaveBeenCalled();
  });
});
