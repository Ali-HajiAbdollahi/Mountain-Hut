// MH-08 Cancel a booking — unit tests (booking service with a fake DAO)
import { describe, it, expect, vi } from 'vitest';

import { createBookingService } from '../../services/bookingService.js';
import { NotFoundError } from '../../errors.js';

const hiker = { uID: 7, name: 'Marco', role: 'hiker' };

function setup({ deleted = true } = {}) {
  const bookings = { cancelOwned: vi.fn(() => deleted), find: vi.fn() };
  const slots = { find: vi.fn(), tables: vi.fn() };
  return { bookings, slots, service: createBookingService(bookings, slots) };
}

describe('bookingService.cancel', () => {
  it('deletes the booking of the logged-in hiker', () => {
    const { bookings, service } = setup();
    expect(service.cancel(12, hiker)).toBeUndefined();
    expect(bookings.cancelOwned).toHaveBeenCalledWith(12, 7);
  });

  it('fails as not found when nothing was deleted (unknown booking or booking of another hiker)', () => {
    const { service } = setup({ deleted: false });
    expect(() => service.cancel(12, hiker)).toThrow(NotFoundError);
  });

  it('does not check the slot time: hikers can cancel at any time (story clarification)', () => {
    const { bookings, slots, service } = setup();
    service.cancel(12, hiker);
    expect(slots.find).not.toHaveBeenCalled();
    expect(bookings.find).not.toHaveBeenCalled();
  });
});
