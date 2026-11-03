// MH-04 Check availability — unit tests (no database, fake DAO)
import { describe, it, expect } from 'vitest';
import { createAvailabilityService } from '../../services/availabilityService.js';
import { ValidationError } from '../../errors.js';

const slot = { tsID: 3, start_time: '2026-12-01 12:00', end_time: '2026-12-01 13:00' };

// freeSeats per table_no, e.g. { 1: 2, 2: 4 }
function serviceWith(freeSeats) {
  const tables = freeSeats && Object.entries(freeSeats)
    .map(([no, free]) => ({ table_no: Number(no), capacity: free, bookedSeats: 0, freeSeats: free }));
  return createAvailabilityService({
    findByStartTime: start => (tables && start === slot.start_time ? { ...slot, tables } : null),
  });
}
const query = partySize => ({ date: '2026-12-01', time: '12:00', partySize });

describe('availabilityService.check — input validation', () => {
  const service = serviceWith({ 1: 4 });

  it.each([
    [{ time: '12:00', partySize: '2' }, 'missing date'],
    [{ date: '01-12-2026', time: '12:00', partySize: '2' }, 'wrong date format'],
    [{ date: '2026-02-30', time: '12:00', partySize: '2' }, 'impossible date'],
    [{ date: '2026-12-01', time: '12', partySize: '2' }, 'wrong time format'],
    [{ date: '2026-12-01', time: '25:00', partySize: '2' }, 'impossible time'],
    [{ date: '2026-12-01', time: '12:00', partySize: '0' }, 'party size 0'],
    [{ date: '2026-12-01', time: '12:00', partySize: '2.5' }, 'decimal party size'],
    [{ date: '2026-12-01', time: '12:00' }, 'missing party size'],
  ])('rejects %j (%s)', input => {
    expect(() => service.check(input)).toThrow(ValidationError);
  });

  it('accepts the party size as a query-string number', () => {
    expect(service.check(query('2')).partySize).toBe(2);
  });
});

describe('availabilityService.check — answer', () => {
  it('is not available when no slot starts at that date and time', () => {
    expect(serviceWith(null).check(query('2')))
      .toEqual({ available: false, partySize: 2, slot: null, allocation: [] });
  });

  it('is not available when the free seats are not enough', () => {
    const result = serviceWith({ 1: 2, 2: 2 }).check(query('5'));
    expect(result.available).toBe(false);
    expect(result.slot).toMatchObject({ tsID: 3 });
    expect(result.allocation).toEqual([]);
  });

  it('uses the single table with the fewest free seats that fits the party', () => {
    expect(serviceWith({ 1: 6, 2: 4, 3: 8 }).check(query('3')))
      .toMatchObject({ available: true, allocation: [{ table_no: 2, seats: 3 }] });
  });

  it('example from the story: 6 free seats over 3 tables of 2, party of 6', () => {
    const result = serviceWith({ 1: 2, 2: 2, 3: 2 }).check(query('6'));
    expect(result.available).toBe(true);
    expect(result.allocation).toEqual([
      { table_no: 1, seats: 2 }, { table_no: 2, seats: 2 }, { table_no: 3, seats: 2 }]);
  });

  it('the allocation always adds up to the party size', () => {
    const result = serviceWith({ 1: 3, 2: 1, 3: 2 }).check(query('5'));
    expect(result.allocation.reduce((n, t) => n + t.seats, 0)).toBe(5);
  });

  // [BUG] When the party must be split, the service fills tables in table_no order
  // (2 + 2 + 1 = three tables) while allocateTables, used by the real booking,
  // picks 4 + 1 = two tables. The availability shown to the user differs from the
  // seats the booking will actually take. Fails until the two algorithms match.
  it('[BUG] splits the party over as few tables as the real booking would', () => {
    const result = serviceWith({ 1: 2, 2: 2, 3: 4 }).check(query('5'));
    expect(result.allocation).toHaveLength(2);
  });
});
