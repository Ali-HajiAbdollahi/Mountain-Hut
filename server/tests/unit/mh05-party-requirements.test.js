// MH-05 Provide party requirements — unit tests (requirement validation in bookingService)
import { describe, it, expect, vi } from 'vitest';
import { createBookingService } from '../../services/bookingService.js';
import { ValidationError } from '../../errors.js';

const hiker = { uID: 7, name: 'Marco', phone: null, role: 'hiker' };

function setup() {
  const bookings = {
    atomic: action => action(),
    duplicate: () => undefined,
    insert: () => 1,
    assign: () => {},
    addRequirements: vi.fn(),
    find: bID => ({ bID }),
  };
  const slots = {
    find: () => ({ tsID: 1, start_time: '2099-01-01 12:00' }),
    tables: () => [{ table_no: 1, seats: 10, free_seats: 10 }],
  };
  return { bookings, service: createBookingService(bookings, slots) };
}
const book = (service, requirements, n_people = 4) =>
  service.create({ tsID: 1, n_people, requirements }, hiker);

describe('party requirements on a new booking', () => {
  it('requirements are optional', () => {
    const { bookings, service } = setup();
    book(service, undefined);
    expect(bookings.addRequirements).toHaveBeenCalledWith(1, []);
  });

  it('stores the three requirements of the story example, with overlapping subsets', () => {
    const { bookings, service } = setup();
    book(service, [
      { allergy: true, description: '1 vegan, peanut allergy', n_people: 1 },
      { allergy: true, description: '1 shellfish allergy', n_people: 1 },
      { allergy: false, description: '2 vegetarians', n_people: 2 },
    ], 3);
    expect(bookings.addRequirements.mock.calls[0][1]).toHaveLength(3);
  });

  it('trims the description and leaves the number of people optional', () => {
    const { bookings, service } = setup();
    book(service, [{ description: '  gluten free  ', allergy: false }]);
    expect(bookings.addRequirements).toHaveBeenCalledWith(1,
      [{ n_people: null, description: 'gluten free', allergy: false }]);
  });

  it('requires a non-empty description', () => {
    const { service } = setup();
    expect(() => book(service, [{ description: '   ', allergy: false }])).toThrow(ValidationError);
    expect(() => book(service, [{ allergy: true }])).toThrow(ValidationError);
  });

  it('requires the allergy flag as a boolean', () => {
    const { service } = setup();
    expect(() => book(service, [{ description: 'nuts' }])).toThrow(/allergy/);
    expect(() => book(service, [{ description: 'nuts', allergy: 'yes' }])).toThrow(/allergy/);
  });

  it('rejects a subset larger than the party', () => {
    const { service } = setup();
    expect(() => book(service, [{ description: 'vegan', allergy: false, n_people: 5 }], 4))
      .toThrow(/exceeds party size/);
  });

  it('rejects an invalid number of people', () => {
    const { service } = setup();
    expect(() => book(service, [{ description: 'vegan', allergy: false, n_people: 0 }])).toThrow(ValidationError);
  });

  it('rejects a non-array value and unknown fields', () => {
    const { service } = setup();
    expect(() => book(service, 'vegan')).toThrow(/array/);
    expect(() => book(service, [{ description: 'vegan', allergy: false, notes: 'x' }])).toThrow(ValidationError);
  });

  it('does not save the booking when a requirement is invalid', () => {
    const { bookings, service } = setup();
    expect(() => book(service, [{ description: '', allergy: false }])).toThrow();
    expect(bookings.addRequirements).not.toHaveBeenCalled();
  });
});
