import { onlyKeys } from './validation.js';
import { ValidationError } from '../errors.js';

export function menuInput(body) {
  onlyKeys(body, ['name', 'description']);
  function requiredText(value, field) {
    if (typeof value !== 'string' || !value.trim()) {
      throw new ValidationError(field + ' must be a non-empty string');
    }
    return value.trim();
  }
  return {
    name: requiredText(body.name, 'name'),
    description: requiredText(body.description, 'description'),
  };
}