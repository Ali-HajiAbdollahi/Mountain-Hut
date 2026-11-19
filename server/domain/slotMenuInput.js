import { onlyKeys } from './validation.js';
import { ValidationError } from '../errors.js';

export function slotMenuInput(body) {
  onlyKeys(body, ['menu']);
  if (typeof body.menu !== 'string' || !body.menu.trim()) {
    throw new ValidationError('menu must be a non-empty string');
  }
  return body.menu.trim();
}