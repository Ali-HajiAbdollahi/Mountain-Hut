import { ValidationError } from '../errors.js';
import { slotTime } from './time.js';
import { onlyKeys } from './validation.js';

function requiredText(value, field) {
  if (typeof value !== 'string' || !value.trim()) {
    throw new ValidationError(`${field} is required`);
  }

  return value.trim();
}

export function hikeInput(body, now = Date.now()) {
  onlyKeys(body, [
    'destination',
    'route',
    'departure_time',
    'expected_return',
    'waypoints',
  ]);

  const destination = requiredText(body.destination, 'destination');
  const route = requiredText(body.route, 'route');
  const departure = slotTime(body.departure_time);
  const expectedReturn = slotTime(body.expected_return);

  if (departure.toMillis() < now) {
    throw new ValidationError('departure_time cannot be in the past');
  }

  if (expectedReturn.toMillis() <= departure.toMillis()) {
    throw new ValidationError('expected_return must be after departure_time');
  }

  const waypoints = body.waypoints === undefined ? [] : body.waypoints;
  if (!Array.isArray(waypoints)) {
    throw new ValidationError('waypoints must be an array');
  }

  const validatedWaypoints = waypoints.map(point => {
    onlyKeys(point, ['name']);
    return { name: requiredText(point.name, 'waypoint name') };
  });

  return {
    destination,
    route,
    departure_time: body.departure_time,
    expected_return: body.expected_return,
    waypoints: validatedWaypoints,
  };
}
