import { DateTime } from 'luxon';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '../errors.js';
import { onlyKeys, positiveInt } from '../domain/validation.js';
import { allocateTables } from '../domain/allocateTables.js';

const CHANGE_WINDOW_MS = 48 * 60 * 60 * 1000;

function requireChangeWindow(createdAt, now = Date.now()) {
  const created = DateTime.fromSQL(createdAt, { zone: 'utc' });

  if (!created.isValid) {
    throw new ValidationError('Invalid booking creation timestamp');
  }

  if (now > created.toMillis() + CHANGE_WINDOW_MS) {
    throw new ConflictError(
      'Booking changes are only allowed within 48 hours after creation',
    );
  }
}

function requirementsInput(rows, partySize) {
  if (!Array.isArray(rows)) {
    throw new ValidationError('requirements must be an array');
  }

  return rows.map(row => {
    onlyKeys(row, ['n_people', 'description', 'allergy']);

    if (typeof row.description !== 'string' || !row.description.trim()) {
      throw new ValidationError('Requirement description is required');
    }

    if (typeof row.allergy !== 'boolean') {
      throw new ValidationError('allergy must be boolean');
    }

    if (
      row.n_people != null &&
      positiveInt(row.n_people, 'requirement n_people') > partySize
    ) {
      throw new ValidationError('Requirement exceeds party size');
    }

    return {
      n_people: row.n_people ?? null,
      description: row.description.trim(),
      allergy: row.allergy,
    };
  });
}

export function createBookingChangeService(bookings, slots) {
  return {
    update(id, body, user) {
      if (user.role !== 'hiker') {
        throw new ForbiddenError('Hiker account required');
      }

      onlyKeys(body, ['tsID', 'n_people', 'requirements']);

      if (Object.keys(body).length === 0) {
        throw new ValidationError('Provide at least one booking field to change');
      }

      return bookings.atomic(() => {
        const current = bookings.find(id);

        if (!current || current.uID !== user.uID) {
          throw new NotFoundError('Booking not found');
        }

        requireChangeWindow(current.created_at);

        const tsID = body.tsID === undefined
          ? current.tsID
          : positiveInt(body.tsID, 'tsID');

        const partySize = body.n_people === undefined
          ? current.n_people
          : positiveInt(body.n_people, 'n_people');

        const replaceRequirements = Object.hasOwn(body, 'requirements');
        const requirementRows = replaceRequirements
          ? body.requirements
          : current.requirements.map(({ n_people, description, allergy }) => ({
              n_people,
              description,
              allergy,
            }));
        const requirements = requirementsInput(requirementRows, partySize);

        const slot = slots.find(tsID);
        if (!slot) {
          throw new NotFoundError('Slot not found');
        }

        const duplicate = bookings.duplicate(user.uID, tsID);
        if (duplicate && duplicate.bID !== id) {
          throw new ConflictError('You already have a booking in this slot');
        }

        const seatingChanged =
          tsID !== current.tsID || partySize !== current.n_people;

        if (seatingChanged) {
          bookings.removeAssignments(id);

          const assignments = allocateTables(slots.tables(tsID), partySize);

          bookings.update(id, { tsID, n_people: partySize });
          bookings.assign(id, tsID, assignments);
        }

        if (replaceRequirements) {
          bookings.replaceRequirements(id, requirements);
        }

        return bookings.find(id);
      });
    },
  };
}