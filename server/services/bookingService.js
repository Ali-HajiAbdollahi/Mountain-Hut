import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../errors.js';
import { onlyKeys, positiveInt } from '../domain/validation.js';
import { requireBookingWindow } from '../domain/time.js';
import { allocateTables } from '../domain/allocateTables.js';

function requirementsInput(rows,n) {
  if (!Array.isArray(rows)) throw new ValidationError('requirements must be an array');
  return rows.map(r=>{
    onlyKeys(r,['n_people','description','allergy']);
    if (typeof r.description !== 'string' || !r.description.trim())
      throw new ValidationError('Requirement description is required');
    if (typeof r.allergy !== 'boolean') throw new ValidationError('allergy must be boolean');
    if (r.n_people != null && positiveInt(r.n_people,'requirement n_people') > n)
      throw new ValidationError('Requirement exceeds party size');
    // Subsets can overlap: do not sum counts across different requirements.
    return {n_people:r.n_people ?? null,description:r.description.trim(),allergy:r.allergy};
  });
}
export function createBookingService(bookings,slots) {
  function owned(id,user) {
    const row=bookings.find(id);
    if (!row || row.uID !== user.uID) throw new NotFoundError('Booking not found');
    return row;
  }
  return {
    owned,
    list: user=>bookings.listForUser(user.uID),
    create(body,user) {
      if (user.role !== 'hiker') throw new ForbiddenError('Hiker account required');
      onlyKeys(body,['tsID','n_people','requirements']);
      const tsID=positiveInt(body.tsID,'tsID');
      const n=positiveInt(body.n_people,'n_people');
      const requirements=requirementsInput(body.requirements ?? [],n);
      return bookings.atomic(()=>{
        const slot=slots.find(tsID);
        if (!slot) throw new NotFoundError('Slot not found');
        requireBookingWindow(slot.start_time);
        if (bookings.duplicate(user.uID,tsID))
          throw new ConflictError('You already have a booking in this slot');
        const assignments=allocateTables(slots.tables(tsID),n);
        const bID=bookings.insert({tsID,uID:user.uID,contact_name:user.name,
          contact_phone:user.phone ?? null,n_people:n});
        bookings.assign(bID,tsID,assignments);
        bookings.addRequirements(bID,requirements);
        return bookings.find(bID);
      });
    },
  };
}