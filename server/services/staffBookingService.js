import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '../errors.js';
import { onlyKeys, positiveInt } from '../domain/validation.js';
import { requireBookingWindow } from '../domain/time.js';
import { allocateTables } from '../domain/allocateTables.js';

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

function hikerInput(value) {
  onlyKeys(value, ['mode', 'uID', 'name', 'email', 'phone', 'password']);

  if (value.mode === 'existing') {
    onlyKeys(value, ['mode', 'uID']);
    return {
      mode: 'existing',
      uID: positiveInt(value.uID, 'hiker uID'),
    };
  }

  if (value.mode === 'temporary') {
    onlyKeys(value, ['mode', 'name', 'phone']);

    if (typeof value.name !== 'string' || !value.name.trim()) {
      throw new ValidationError('Hiker name is required');
    }

    if (value.phone != null && typeof value.phone !== 'string') {
      throw new ValidationError('phone must be a string');
    }

    return {
      mode: 'temporary',
      name: value.name.trim(),
      phone: value.phone?.trim() || null,
    };
  }

  if (value.mode === 'register') {
    onlyKeys(value, ['mode', 'name', 'email', 'phone', 'password']);

    for (const field of ['name', 'email', 'phone', 'password']) {
      if (typeof value[field] !== 'string' || !value[field].trim()) {
        throw new ValidationError(`${field} is required`);
      }
    }

    return {
      mode: 'register',
      profile: {
        name: value.name,
        email: value.email,
        phone: value.phone,
        password: value.password,
      },
    };
  }

  throw new ValidationError('hiker mode must be existing, temporary, or register');
}

export function createStaffBookingService(users, bookings, slots, auth) {
  return {
    searchHikers(query, employee) {
      if (employee.role !== 'employee') {
        throw new ForbiddenError('Employee account required');
      }

      if (typeof query !== 'string' || query.trim().length < 2) {
        throw new ValidationError('Search query must contain at least 2 characters');
      }

      return users.searchHikers(query);
    },

    create(body, employee) {
      if (employee.role !== 'employee') {
        throw new ForbiddenError('Employee account required');
      }

      onlyKeys(body, ['hiker', 'tsID', 'n_people', 'requirements']);

      const hiker = hikerInput(body.hiker);
      const tsID = positiveInt(body.tsID, 'tsID');
      const partySize = positiveInt(body.n_people, 'n_people');
      const requirements = requirementsInput(body.requirements ?? [], partySize);

      return bookings.atomic(() => {
        const slot = slots.find(tsID);
        if (!slot) {
          throw new NotFoundError('Slot not found');
        }

        requireBookingWindow(slot.start_time);

        let profile;

        if (hiker.mode === 'existing') {
          profile = users.findById(hiker.uID);

          if (!profile || profile.role !== 'hiker') {
            throw new NotFoundError('Hiker not found');
          }

          if (bookings.duplicate(profile.uID, tsID)) {
            throw new ConflictError('This hiker already has a booking in this slot');
          }
        } else if (hiker.mode === 'register') {
          profile = auth.register(hiker.profile);
        } else {
          profile = {
            uID: null,
            name: hiker.name,
            phone: hiker.phone,
          };
        }

        const assignments = allocateTables(slots.tables(tsID), partySize);
        const bID = bookings.insert({
          tsID,
          uID: profile.uID,
          contact_name: profile.name,
          contact_phone: profile.phone ?? null,
          n_people: partySize,
          created_by: employee.uID,
        });

        bookings.assign(bID, tsID, assignments);
        bookings.addRequirements(bID, requirements);

        return bookings.find(bID);
      });
    },
  };
}