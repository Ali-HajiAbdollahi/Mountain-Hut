// MH-07 Reserve for an hiker — unit tests (no database, fake DAOs)
import { describe, it, expect, vi, afterEach } from 'vitest';
import { createStaffBookingService } from '../../services/staffBookingService.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../errors.js';

const employee = { uID: 1, role: 'employee' };
const registered = { uID: 5, name: 'Sara Verdi', email: 'sara@mail.it', phone: '333', role: 'hiker' };

function setup({ user = registered, duplicate, slotStart = '2099-01-01 12:00' } = {}) {
  const users = { searchHikers: vi.fn(() => [registered]), findById: vi.fn(() => user) };
  const bookings = {
    atomic: action => action(),
    duplicate: vi.fn(() => duplicate),
    insert: vi.fn(() => 20),
    assign: vi.fn(),
    addRequirements: vi.fn(),
    find: vi.fn(bID => ({ bID })),
  };
  const slots = {
    find: () => ({ tsID: 1, start_time: slotStart }),
    tables: () => [{ table_no: 1, seats: 6, free_seats: 6 }],
  };
  const auth = { register: vi.fn(profile => ({ uID: 9, ...profile, role: 'hiker' })) };
  return { users, bookings, auth, service: createStaffBookingService(users, bookings, slots, auth) };
}
const reserve = (service, hiker, extra = {}) =>
  service.create({ hiker, tsID: 1, n_people: 3, ...extra }, employee);

describe('staffBookingService.searchHikers', () => {
  it('searches the hikers by name, phone or email', () => {
    const { users, service } = setup();
    expect(service.searchHikers('Sara', employee)).toEqual([registered]);
    expect(users.searchHikers).toHaveBeenCalledWith('Sara');
  });

  it('requires at least 2 characters', () => {
    const { service } = setup();
    expect(() => service.searchHikers('S', employee)).toThrow(ValidationError);
    expect(() => service.searchHikers(undefined, employee)).toThrow(ValidationError);
  });

  it('is reserved to employees', () => {
    const { service } = setup();
    expect(() => service.searchHikers('Sara', { uID: 5, role: 'hiker' })).toThrow(ForbiddenError);
  });
});

describe('staffBookingService.create', () => {
  it('is reserved to employees', () => {
    const { service } = setup();
    expect(() => service.create({ hiker: { mode: 'existing', uID: 5 }, tsID: 1, n_people: 2 },
      { uID: 5, role: 'hiker' })).toThrow(ForbiddenError);
  });

  it('books for a hiker already in the system and records the employee', () => {
    const { bookings, service } = setup();
    reserve(service, { mode: 'existing', uID: 5 });
    expect(bookings.insert).toHaveBeenCalledWith({
      tsID: 1, uID: 5, contact_name: 'Sara Verdi', contact_phone: '333', n_people: 3, created_by: 1 });
  });

  it('fails when the existing hiker is not found or is not a hiker', () => {
    expect(() => reserve(setup({ user: null }).service, { mode: 'existing', uID: 5 })).toThrow(NotFoundError);
    expect(() => reserve(setup({ user: { ...registered, role: 'employee' } }).service,
      { mode: 'existing', uID: 5 })).toThrow(NotFoundError);
  });

  it('keeps the rule of one booking per slot for an existing hiker', () => {
    const { service } = setup({ duplicate: { bID: 3 } });
    expect(() => reserve(service, { mode: 'existing', uID: 5 })).toThrow(ConflictError);
  });

  it('quick entry: a temporary hiker with name only has no account', () => {
    const { bookings, service } = setup();
    reserve(service, { mode: 'temporary', name: '  Rossi Group ' });
    expect(bookings.insert).toHaveBeenCalledWith(expect.objectContaining(
      { uID: null, contact_name: 'Rossi Group', contact_phone: null, created_by: 1 }));
  });

  it('quick entry: phone is optional but must be a string', () => {
    const { bookings, service } = setup();
    reserve(service, { mode: 'temporary', name: 'Rossi', phone: '3335550000' });
    expect(bookings.insert.mock.calls[0][0].contact_phone).toBe('3335550000');
    expect(() => reserve(service, { mode: 'temporary', name: 'Rossi', phone: 333 })).toThrow(ValidationError);
    expect(() => reserve(service, { mode: 'temporary', name: '' })).toThrow(ValidationError);
  });

  it('full details: creates a regular hiker profile with a random password that must be changed', () => {
    const { auth, bookings, service } = setup();
    const profile = { name: 'Luca Neri', email: 'luca@mail.it', phone: '334' };
    const { generatedPassword } = reserve(service, { mode: 'register', ...profile });
    expect(auth.register).toHaveBeenCalledWith({ ...profile, password: generatedPassword, mustChangePassword: true });
    expect(generatedPassword).toMatch(/^[A-Za-z0-9_-]{20,}$/);
    expect(bookings.insert.mock.calls[0][0].uID).toBe(9);
  });

  it('full details: every generated password is different', () => {
    const { service } = setup();
    const passwords = [1, 2, 3].map(i =>
      reserve(service, { mode: 'register', name: 'Luca', email: `l${i}@mail.it`, phone: '334' }).generatedPassword);
    expect(new Set(passwords).size).toBe(3);
  });

  it('full details: name, email and phone are required and a password is not accepted', () => {
    const { service } = setup();
    const full = { mode: 'register', name: 'Luca', email: 'luca@mail.it', phone: '334' };
    for (const field of ['name', 'email', 'phone'])
      expect(() => reserve(service, { ...full, [field]: '' })).toThrow(new RegExp(field));
    expect(() => reserve(service, { ...full, password: 'password123' })).toThrow(/Unexpected field/);
  });

  it('only the full details mode returns a password', () => {
    const { service } = setup();
    expect(reserve(service, { mode: 'existing', uID: 5 }).generatedPassword).toBeNull();
    expect(reserve(service, { mode: 'temporary', name: 'Rossi' }).generatedPassword).toBeNull();
  });

  describe('time of the slot', () => {
    // 1 Dec 2026, 12:00 Europe/Rome = 11:00 UTC
    const slotStart = '2026-12-01 12:00';
    const at = iso => { vi.useFakeTimers(); vi.setSystemTime(new Date(iso)); };
    afterEach(() => vi.useRealTimers());

    it('accepts a reservation made less than 2 hours before the slot', () => {
      at('2026-12-01T10:30:00Z');
      expect(() => reserve(setup({ slotStart }).service, { mode: 'existing', uID: 5 })).not.toThrow();
    });

    it('accepts a reservation until the very last second before the start', () => {
      at('2026-12-01T10:59:59Z');
      expect(() => reserve(setup({ slotStart }).service, { mode: 'existing', uID: 5 })).not.toThrow();
    });

    it('refuses a reservation at or after the start of the slot', () => {
      for (const now of ['2026-12-01T11:00:00Z', '2026-12-01T11:30:00Z']) {
        at(now);
        const { service, bookings } = setup({ slotStart });
        expect(() => reserve(service, { mode: 'existing', uID: 5 })).toThrow(ConflictError);
        expect(bookings.insert).not.toHaveBeenCalled();
      }
    });
  });

  it('rejects an unknown mode or fields that do not belong to the mode', () => {
    const { service } = setup();
    expect(() => reserve(service, { mode: 'guest', name: 'x' })).toThrow(ValidationError);
    expect(() => reserve(service, { mode: 'temporary', name: 'x', email: 'x@y.it' })).toThrow(ValidationError);
    expect(() => reserve(service, { mode: 'existing', uID: 5, name: 'x' })).toThrow(ValidationError);
  });

  it('saves the party requirements too', () => {
    const { bookings, service } = setup();
    reserve(service, { mode: 'existing', uID: 5 },
      { requirements: [{ description: 'nut allergy', allergy: true, n_people: 1 }] });
    expect(bookings.addRequirements).toHaveBeenCalledWith(20,
      [{ description: 'nut allergy', allergy: true, n_people: 1 }]);
  });
});
