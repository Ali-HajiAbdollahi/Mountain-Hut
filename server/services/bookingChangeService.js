import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '../errors.js';
import { onlyKeys, positiveInt } from '../domain/validation.js';
import { requireBookingWindow, slotTime } from '../domain/time.js';
import { allocateTables } from '../domain/allocateTables.js';

const CHANGE_WINDOW_MS = 48 * 60 * 60 * 1000;

function requireChangeWindow(startTime, now = Date.now()) {
  const mealStart = slotTime(startTime);

  if (mealStart.toMillis() - now < CHANGE_WINDOW_MS) {
    throw new ConflictError(
      'Booking changes must be made at least 48 hours before the meal',
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

function resizeCurrentAssignments(currentAssignments, availableTables, partySize) {
  const capacityByTable = new Map(
    availableTables.map(table => [table.table_no, table.free_seats]),
  );
  const assignments = currentAssignments
    .map(({ table_no, seats }) => ({ table_no, seats }))
    .sort((a, b) => a.table_no - b.table_no);
  const assignedSeats = assignments.reduce((total, table) => total + table.seats, 0);

  if (partySize < assignedSeats) {
    let seatsToRelease = assignedSeats - partySize;
    for (let i = assignments.length - 1; i >= 0 && seatsToRelease > 0; i--) {
      const released = Math.min(assignments[i].seats, seatsToRelease);
      assignments[i].seats -= released;
      seatsToRelease -= released;
    }
  } else if (partySize > assignedSeats) {
    let seatsToAdd = partySize - assignedSeats;
    for (const assignment of assignments) {
      const capacity = capacityByTable.get(assignment.table_no) ?? assignment.seats;
      const added = Math.min(capacity - assignment.seats, seatsToAdd);
      assignment.seats += added;
      seatsToAdd -= added;
      if (seatsToAdd === 0) break;
    }
  }

  return assignments.filter(table => table.seats > 0);
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

        requireChangeWindow(current.start_time);

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

        if (tsID !== current.tsID) {
          requireBookingWindow(slot.start_time);
        }

        const duplicate = bookings.duplicate(user.uID, tsID);
        if (duplicate && duplicate.bID !== id) {
          throw new ConflictError('You already have a booking in this slot');
        }

        const seatingChanged =
          tsID !== current.tsID || partySize !== current.n_people;

        if (seatingChanged) {
          let assignments;

          // If only the party size changed, first see whether the booking can
          // stay on its currently assigned tables. Add this booking's seats
          // back to each table's free-seat count because slots.tables() excludes
          // seats already occupied by this booking.
          if (tsID === current.tsID && partySize !== current.n_people) {
            const existingAssignments = current.tables ?? [];
            const currentSeatsByTable = new Map(
              existingAssignments.map(table => [table.table_no, table.seats]),
            );
            const currentTables = slots.tables(tsID)
              .filter(table => currentSeatsByTable.has(table.table_no))
              .map(table => ({
                ...table,
                free_seats: table.free_seats + currentSeatsByTable.get(table.table_no),
              }));
            const availableOnCurrentTables = currentTables.reduce(
              (total, table) => total + table.free_seats,
              0,
            );

            if (availableOnCurrentTables >= partySize) {
              assignments = resizeCurrentAssignments(
                existingAssignments,
                currentTables,
                partySize,
              );
            }
          }

          bookings.removeAssignments(id);

          // If the old tables cannot fit the new party (or the booking moved
          // to another slot), fall back to the normal MH-01 allocation rules.
          if (!assignments) {
            assignments = allocateTables(slots.tables(tsID), partySize);
          }

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
