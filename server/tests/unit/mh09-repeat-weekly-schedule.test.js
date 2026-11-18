// MH-09 Repeat a weekly schedule — unit tests (week mapping + service with fake DAO)
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { readWeeks, mapWeeklySlot } from '../../domain/weekSchedule.js';
import { createSlotService } from '../../services/slotService.js';
import { ConflictError, ValidationError } from '../../errors.js';

// 1 Dec 2026 (a Tuesday), 08:00 Europe/Rome
const NOW = new Date('2026-12-01T07:00:00Z');

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(NOW);
});
afterEach(() => {
  vi.useRealTimers();
});

describe('readWeeks', () => {
  it('returns the source and target weeks, Monday to next Monday, and the shift in days', () => {
    expect(readWeeks({ source_week: '2026-12-07', target_week: '2026-12-14' })).toEqual({
      from: '2026-12-07 00:00',
      to: '2026-12-14 00:00',
      targetFrom: '2026-12-14 00:00',
      targetTo: '2026-12-21 00:00',
      days: 7,
    });
  });

  it('can copy several weeks ahead', () => {
    expect(readWeeks({ source_week: '2026-12-07', target_week: '2027-01-04' }).days).toBe(28);
  });

  it('can copy a later week onto an earlier one', () => {
    expect(readWeeks({ source_week: '2026-12-14', target_week: '2026-12-07' }).days).toBe(-7);
  });

  it('counts whole days across a clock change', () => {
    expect(readWeeks({ source_week: '2027-03-22', target_week: '2027-03-29' }).days).toBe(7);
  });

  it('requires both weeks to start on a Monday', () => {
    expect(() => readWeeks({ source_week: '2026-12-08', target_week: '2026-12-14' }))
      .toThrow('Expected a Monday');
    expect(() => readWeeks({ source_week: '2026-12-07', target_week: '2026-12-13' }))
      .toThrow('Expected a Monday');
  });

  it('refuses to copy a week onto itself', () => {
    expect(() => readWeeks({ source_week: '2026-12-07', target_week: '2026-12-07' }))
      .toThrow('Choose different weeks');
  });

  it.each([
    ['missing target', { source_week: '2026-12-07' }],
    ['wrong format', { source_week: '07/12/2026', target_week: '2026-12-14' }],
    ['impossible date', { source_week: '2026-02-30', target_week: '2026-12-14' }],
    ['unknown field', { source_week: '2026-12-07', target_week: '2026-12-14', days: [1, 2] }],
  ])('rejects invalid input (%s)', (_, body) => {
    expect(() => readWeeks(body)).toThrow(ValidationError);
  });
});

describe('mapWeeklySlot', () => {
  it('moves the slot by the given days and keeps its times', () => {
    expect(mapWeeklySlot({ tsID: 4, start_time: '2026-12-09 12:00', end_time: '2026-12-09 13:30' }, 7))
      .toEqual({ sourceTsID: 4, start_time: '2026-12-16 12:00', end_time: '2026-12-16 13:30' });
  });

  it('keeps the local times across a clock change when the duration does not change', () => {
    expect(mapWeeklySlot({ tsID: 1, start_time: '2027-03-21 12:00', end_time: '2027-03-21 13:00' }, 7))
      .toMatchObject({ start_time: '2027-03-28 12:00', end_time: '2027-03-28 13:00' });
  });

  it('refuses a slot whose duration would change with the clock change', () => {
    expect(() => mapWeeklySlot({ tsID: 1, start_time: '2027-03-21 01:00', end_time: '2027-03-21 04:00' }, 7))
      .toThrow('Clock change would alter slot duration');
  });

  it('refuses a copy that would land in the past', () => {
    expect(() => mapWeeklySlot({ tsID: 1, start_time: '2026-12-07 07:00', end_time: '2026-12-07 08:00' }, -7))
      .toThrow('Slot must start in the future');
  });
});

describe('slotService.repeatWeek', () => {
  const body = { source_week: '2026-12-07', target_week: '2026-12-14' };
  const sourceSlots = [
    { tsID: 1, start_time: '2026-12-07 12:00', end_time: '2026-12-07 13:00' },
    { tsID: 2, start_time: '2026-12-13 19:00', end_time: '2026-12-13 20:30' },
  ];

  function fakeDao({ booked = false, slots = sourceSlots, replaced = 0 } = {}) {
    const order = [];
    const dao = {
      order,
      atomic: vi.fn(action => { order.push('begin'); const r = action(); order.push('commit'); return r; }),
      targetHasBookings: vi.fn(() => { order.push('check bookings'); return booked; }),
      listRange: vi.fn(() => slots),
      deleteWeek: vi.fn(() => { order.push('delete target'); return replaced; }),
      copyWeek: vi.fn(copies => { order.push('copy'); return copies.map((_, i) => 100 + i); }),
    };
    return dao;
  }

  it('copies every slot of the source week into the target week', () => {
    const dao = fakeDao();
    const result = createSlotService(dao).repeatWeek(body);

    expect(dao.listRange).toHaveBeenCalledWith('2026-12-07 00:00', '2026-12-14 00:00');
    expect(dao.copyWeek).toHaveBeenCalledWith([
      { sourceTsID: 1, start_time: '2026-12-14 12:00', end_time: '2026-12-14 13:00' },
      { sourceTsID: 2, start_time: '2026-12-20 19:00', end_time: '2026-12-20 20:30' },
    ]);
    expect(result).toEqual({ slotIds: [100, 101], replacedCount: 0 });
  });

  it('replaces the slots of the target week and reports how many were replaced', () => {
    const dao = fakeDao({ replaced: 3 });
    expect(createSlotService(dao).repeatWeek(body).replacedCount).toBe(3);
    expect(dao.deleteWeek).toHaveBeenCalledWith('2026-12-14 00:00', '2026-12-21 00:00');
  });

  it('checks, deletes and copies inside one transaction, deleting before copying', () => {
    const dao = fakeDao();
    createSlotService(dao).repeatWeek(body);
    expect(dao.order).toEqual(['begin', 'check bookings', 'delete target', 'copy', 'commit']);
  });

  it('refuses a target week with reservations and changes nothing', () => {
    const dao = fakeDao({ booked: true });
    expect(() => createSlotService(dao).repeatWeek(body))
      .toThrow(new ConflictError('The target week has reservations: it cannot be replaced'));
    expect(dao.targetHasBookings).toHaveBeenCalledWith('2026-12-14 00:00', '2026-12-21 00:00');
    expect(dao.deleteWeek).not.toHaveBeenCalled();
    expect(dao.copyWeek).not.toHaveBeenCalled();
  });

  it('refuses an empty source week without touching the target week', () => {
    const dao = fakeDao({ slots: [] });
    expect(() => createSlotService(dao).repeatWeek(body)).toThrow('Source week has no slots');
    expect(dao.deleteWeek).not.toHaveBeenCalled();
  });

  it('validates every copy before deleting the target week', () => {
    const dao = fakeDao({ slots: [
      sourceSlots[0],
      { tsID: 3, start_time: '2027-03-21 01:00', end_time: '2027-03-21 04:00' },
    ] });
    expect(() => createSlotService(dao).repeatWeek(body)).toThrow(ValidationError);
    expect(dao.deleteWeek).not.toHaveBeenCalled();
    expect(dao.copyWeek).not.toHaveBeenCalled();
  });

  it('propagates a failing copy, so the transaction is rolled back', () => {
    const dao = fakeDao();
    dao.copyWeek.mockImplementation(() => { throw new ConflictError('Slot overlaps an existing slot'); });
    expect(() => createSlotService(dao).repeatWeek(body)).toThrow(ConflictError);
    expect(dao.order).not.toContain('commit');
  });

  it('does not open a transaction when the weeks are invalid', () => {
    const dao = fakeDao();
    expect(() => createSlotService(dao).repeatWeek({ source_week: '2026-12-07', target_week: '2026-12-07' }))
      .toThrow(ValidationError);
    expect(dao.atomic).not.toHaveBeenCalled();
  });
});
