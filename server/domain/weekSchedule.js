import { DateTime } from 'luxon';
import { HUT_ZONE, dateOnly, validateInterval } from './time.js';
import { onlyKeys } from './validation.js';
import { ValidationError } from '../errors.js';

function monday(value) {
  const date = DateTime.fromISO(dateOnly(value), { zone: HUT_ZONE });
  if (date.weekday !== 1) throw new ValidationError('Expected a Monday');
  return date;
}

export function readWeeks(body) {
  onlyKeys(body, ['source_week', 'target_week']);
  const source = monday(body.source_week);
  const target = monday(body.target_week);
  if (source.equals(target)) throw new ValidationError('Choose different weeks');
  return {
    from: source.toISODate() + ' 00:00',
    to: source.plus({ weeks: 1 }).toISODate() + ' 00:00',
    days: target.diff(source, 'days').days,
  };
}

function shiftLocal(value, days) {
  const date = DateTime.fromISO(value.slice(0, 10), { zone: HUT_ZONE });
  return date.plus({ days }).toISODate() + value.slice(10);
}

export function mapWeeklySlot(slot, days) {
  const start_time = shiftLocal(slot.start_time, days);
  const end_time = shiftLocal(slot.end_time, days);
  validateInterval(start_time, end_time);
  return { sourceTsID: slot.tsID, start_time, end_time };
}