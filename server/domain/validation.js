import { ValidationError } from '../errors.js';

export function object(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new ValidationError('Expected a JSON object');
  return value;
}
export function onlyKeys(value, allowed) {
  object(value);
  if (Object.keys(value).some(k => !allowed.includes(k)))
    throw new ValidationError('Unexpected field');
}
export function positiveInt(value, name) {
  if (!Number.isSafeInteger(value) || value <= 0)
    throw new ValidationError(`${name} must be a positive integer`);
  return value;
}
export function pathId(value) {
  if (typeof value !== 'string' || !/^[1-9]\d*$/.test(value))
    throw new ValidationError('Invalid identifier');
  return positiveInt(Number(value), 'id');
}