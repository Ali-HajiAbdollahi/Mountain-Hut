// MH-02 Define slot capacity — unit tests (no database, fake DAO)
import { describe, it, expect, vi } from 'vitest';
import { slotTime, dateOnly, validateInterval } from '../../domain/time.js';
import { createSlotService } from '../../services/slotService.js';
import { ConflictError, NotFoundError, ValidationError } from '../../errors.js';

describe('slotTime', () => {
  it('parses a local Europe/Rome time', () => {
    expect(slotTime('2026-12-01 12:30').toISO()).toBe('2026-12-01T12:30:00.000+01:00');
  });

  it.each(['2026-12-01T12:30', '2026-12-01 12:30:00', '01/12/2026 12:30', 42])(
    'rejects the wrong format %s', value => {
      expect(() => slotTime(value)).toThrow(ValidationError);
    });

  it('rejects impossible dates', () => {
    expect(() => slotTime('2026-02-30 12:00')).toThrow(ValidationError);
  });

  it('rejects a time skipped by the switch to summer time', () => {
    expect(() => slotTime('2026-03-29 02:30')).toThrow(ValidationError);
  });

  it('rejects an ambiguous time during the switch back to winter time', () => {
    expect(() => slotTime('2026-10-25 02:30')).toThrow(/Ambiguous/);
  });
});

describe('dateOnly', () => {
  it('accepts YYYY-MM-DD', () => {
    expect(dateOnly('2026-12-01')).toBe('2026-12-01');
  });

  it('rejects other formats and impossible dates', () => {
    expect(() => dateOnly('2026-12-1')).toThrow(ValidationError);
    expect(() => dateOnly('2026-13-01')).toThrow(ValidationError);
    expect(() => dateOnly(undefined)).toThrow(ValidationError);
  });
});

describe('validateInterval', () => {
  const now = Date.parse('2026-12-01T07:00:00Z');

  it('accepts a future slot of any duration, also across midnight', () => {
    expect(() => validateInterval('2026-12-01 12:00', '2026-12-01 13:00', now)).not.toThrow();
    expect(() => validateInterval('2026-12-01 23:30', '2026-12-02 00:15', now)).not.toThrow();
  });

  it('rejects an end that is not after the start', () => {
    expect(() => validateInterval('2026-12-01 13:00', '2026-12-01 13:00', now)).toThrow(ValidationError);
    expect(() => validateInterval('2026-12-01 13:00', '2026-12-01 12:00', now)).toThrow(ValidationError);
  });

  it('rejects a slot that has already started', () => {
    expect(() => validateInterval('2026-12-01 08:00', '2026-12-01 09:00', now)).toThrow(ValidationError);
  });
});

describe('slotService', () => {
  // Small in-memory replacement for slotDao
  function fakeDao() {
    const slots = new Map();
    const tables = new Map();
    let nextId = 1;
    return {
      atomic: action => action(),
      find: id => slots.get(id),
      tables: id => (tables.get(id) ?? []).map(t => ({ ...t, free_seats: t.seats })),
      sameInterval: (a, b) => [...slots.values()].find(s => s.start_time === a && s.end_time === b),
      list: date => [...slots.values()].filter(s => s.start_time.startsWith(date)),
      insert: vi.fn((a, b) => {
        const tsID = nextId++;
        slots.set(tsID, { tsID, start_time: a, end_time: b });
        return tsID;
      }),
      insertTables: vi.fn((id, rows) => tables.set(id, [...(tables.get(id) ?? []), ...rows])),
    };
  }
  const lunch = { start_time: '2099-01-01 12:00', end_time: '2099-01-01 13:00' };
  const layout = [{ table_no: 1, seats: 2 }, { table_no: 2, seats: 6 }];

  it('creates a slot and computes its capacity', () => {
    const service = createSlotService(fakeDao());
    const slot = service.create({ ...lunch, tables: layout });
    expect(slot).toMatchObject({ tsID: 1, capacity: 8, free_seats: 8 });
    expect(slot.tables).toHaveLength(2);
  });

  it('reuses the table layout of another slot', () => {
    const service = createSlotService(fakeDao());
    service.create({ ...lunch, tables: layout });
    const second = service.create({
      start_time: '2099-01-01 13:00', end_time: '2099-01-01 14:00', copy_from_tsID: 1 });
    expect(second.tables.map(({ table_no, seats }) => ({ table_no, seats }))).toEqual(layout);
  });

  it('requires exactly one of tables and copy_from_tsID', () => {
    const service = createSlotService(fakeDao());
    expect(() => service.create(lunch)).toThrow(ValidationError);
    expect(() => service.create({ ...lunch, tables: layout, copy_from_tsID: 1 })).toThrow(ValidationError);
  });

  it('fails when the slot to copy from does not exist', () => {
    const service = createSlotService(fakeDao());
    expect(() => service.create({ ...lunch, copy_from_tsID: 42 })).toThrow(NotFoundError);
  });

  it('rejects duplicate table numbers and invalid seats', () => {
    const service = createSlotService(fakeDao());
    expect(() => service.create({ ...lunch, tables: [{ table_no: 1, seats: 2 }, { table_no: 1, seats: 4 }] }))
      .toThrow(/Duplicate/);
    expect(() => service.create({ ...lunch, tables: [{ table_no: 1, seats: 0 }] })).toThrow(ValidationError);
    expect(() => service.create({ ...lunch, tables: [{ table_no: 1, seats: '4' }] })).toThrow(ValidationError);
  });

  it('rejects a second slot with the same start and end', () => {
    const service = createSlotService(fakeDao());
    service.create({ ...lunch, tables: layout });
    expect(() => service.create({ ...lunch, tables: layout })).toThrow(ConflictError);
  });

  it('defines tables only once for a slot without layout', () => {
    const dao = fakeDao();
    const service = createSlotService(dao);
    const id = dao.insert(lunch.start_time, lunch.end_time);
    expect(service.defineTables(id, { tables: layout }).capacity).toBe(8);
    expect(() => service.defineTables(id, { tables: layout })).toThrow(ConflictError);
  });

  it('lists the slots of a date with their capacity', () => {
    const service = createSlotService(fakeDao());
    service.create({ ...lunch, tables: layout });
    expect(service.list('2099-01-01')).toHaveLength(1);
    expect(service.list('2099-01-02')).toEqual([]);
    expect(() => service.list('tomorrow')).toThrow(ValidationError);
  });
});
