import { DateTime } from 'luxon';
import { ValidationError, ConflictError } from '../errors.js';

export const HUT_ZONE = 'Europe/Rome';
const FORMAT = 'yyyy-MM-dd HH:mm';

export function slotTime(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(value))
    throw new ValidationError('Expected YYYY-MM-DD HH:MM in Europe/Rome');
  const dt = DateTime.fromFormat(value, FORMAT, { zone: HUT_ZONE });
  if (!dt.isValid || dt.toFormat(FORMAT) !== value)
    throw new ValidationError('Invalid local date/time');
  // The schema has no offset: ambiguous autumn hours cannot be represented.
  if (dt.getPossibleOffsets().length !== 1)
    throw new ValidationError('Ambiguous local time: choose another time');
  return dt;
}
export function dateOnly(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value))
    throw new ValidationError('Expected YYYY-MM-DD');
  const dt = DateTime.fromFormat(value, 'yyyy-MM-dd', { zone: HUT_ZONE });
  if (!dt.isValid || dt.toFormat('yyyy-MM-dd') !== value)
    throw new ValidationError('Invalid date');
  return value;
}
export function validateInterval(start, end, now = Date.now()) {
  const a = slotTime(start), b = slotTime(end);
  if (b.toMillis() <= a.toMillis())
    throw new ValidationError('end_time must be after start_time');
  if (a.toMillis() <= now) throw new ValidationError('Slot must start in the future');
}
export function requireBookingWindow(start, now = Date.now()) {
  if (slotTime(start).toMillis() - now < 2 * 60 * 60 * 1000)
    throw new ConflictError('Bookings close two hours before the slot');
}