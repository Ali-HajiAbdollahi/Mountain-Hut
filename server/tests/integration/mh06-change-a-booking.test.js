// MH-06 Change a booking — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addSlot, loginAs, seatsOf } from '../helpers/app.js';

let ctx, lunch, secondLunch, marco, bID;

// SQLite fills created_at with the real clock, not the frozen one: set it explicitly
const setCreatedAt = (id, value) =>
  ctx.db.prepare('UPDATE bookings SET created_at = ? WHERE bID = ?').run(value, id);

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome = 07:00 UTC
  ctx = createTestContext();
  addHiker(ctx);
  addHiker(ctx, { name: 'Sara Verdi', email: 'sara@mail.it' });
  // more than 48 hours ahead, so the booking can still be changed
  lunch = addSlot(ctx, '2026-12-05 12:00', '2026-12-05 13:00', { 1: 2, 2: 4, 3: 6 });
  secondLunch = addSlot(ctx, '2026-12-05 13:00', '2026-12-05 14:00', { 1: 4 });
  marco = await loginAs(ctx, 'marco@mail.it');
  const res = await marco.post('/api/bookings').send({
    tsID: lunch, n_people: 2, requirements: [{ description: 'vegan', allergy: false, n_people: 1 }] });
  bID = res.body.booking.bID;
  setCreatedAt(bID, '2026-12-01 06:00:00'); // booked one hour ago
});
afterEach(() => {
  vi.useRealTimers();
});

describe('PATCH /api/bookings/:id', () => {
  it('changes the party size and re-allocates the tables', async () => {
    const res = await marco.patch(`/api/bookings/${bID}`).send({ n_people: 5 });
    expect(res.status).toBe(200);
    expect(res.body.booking.n_people).toBe(5);
    expect(seatsOf(ctx, bID)).toEqual({ 3: 5 });
  });

  it('re-seats the party on its own freed seats when the slot is otherwise full', async () => {
    const sara = await loginAs(ctx, 'sara@mail.it');
    await sara.post('/api/bookings').send({ tsID: lunch, n_people: 10 }); // tables 2 and 3
    const res = await marco.patch(`/api/bookings/${bID}`).send({ n_people: 1 });
    expect(res.status).toBe(200);
    expect(seatsOf(ctx, bID)).toEqual({ 1: 1 });
  });

  it('moves the booking to another slot and frees the old seats', async () => {
    const res = await marco.patch(`/api/bookings/${bID}`).send({ tsID: secondLunch });
    expect(res.status).toBe(200);
    expect(res.body.booking).toMatchObject({ tsID: secondLunch, start_time: '2026-12-05 13:00' });
    const old = await request(ctx.app).get(`/api/timeslots/${lunch}`);
    expect(old.body.free_seats).toBe(12);
  });

  it('replaces the requirements without touching the tables', async () => {
    const before = seatsOf(ctx, bID);
    const res = await marco.patch(`/api/bookings/${bID}`)
      .send({ requirements: [{ description: 'nut allergy', allergy: true, n_people: 2 }] });
    expect(res.body.booking.requirements).toMatchObject([{ description: 'nut allergy', allergy: true }]);
    expect(seatsOf(ctx, bID)).toEqual(before);
  });

  it('verifies availability: a party that does not fit is refused and nothing changes', async () => {
    const res = await marco.patch(`/api/bookings/${bID}`).send({ tsID: secondLunch, n_people: 5 });
    expect(res.status).toBe(409);
    const unchanged = await marco.get(`/api/bookings/${bID}`);
    expect(unchanged.body).toMatchObject({ tsID: lunch, n_people: 2 });
    expect(seatsOf(ctx, bID)).toEqual({ 1: 2 });
  });

  // [BUG] MH-06 rule (confirmed by the team): changes are allowed until 48 hours before
  // the booked meal. The code counts 48 hours from created_at instead. Fails until fixed.
  it('[BUG] allows changes to an old booking while the meal is more than 48 hours away', async () => {
    setCreatedAt(bID, '2026-11-01 10:00:00'); // booked a month ago, meal on 5 Dec
    expect((await marco.patch(`/api/bookings/${bID}`).send({ n_people: 3 })).status).toBe(200);
  });

  it('[BUG] refuses changes less than 48 hours before the meal', async () => {
    const tomorrow = addSlot(ctx, '2026-12-02 12:00', '2026-12-02 13:00', { 1: 4 });
    const res = await marco.post('/api/bookings').send({ tsID: tomorrow, n_people: 2 });
    setCreatedAt(res.body.booking.bID, '2026-12-01 06:00:00'); // booked one hour ago
    expect((await marco.patch(`/api/bookings/${res.body.booking.bID}`).send({ n_people: 3 })).status).toBe(409);
  });

  it('refuses to move into a slot where the hiker already has a booking', async () => {
    await marco.post('/api/bookings').send({ tsID: secondLunch, n_people: 1 });
    expect((await marco.patch(`/api/bookings/${bID}`).send({ tsID: secondLunch })).status).toBe(409);
  });

  it('hides bookings of other hikers', async () => {
    const sara = await loginAs(ctx, 'sara@mail.it');
    expect((await sara.patch(`/api/bookings/${bID}`).send({ n_people: 3 })).status).toBe(404);
  });

  it('returns 400 for an empty change or unknown fields', async () => {
    expect((await marco.patch(`/api/bookings/${bID}`).send({})).status).toBe(400);
    expect((await marco.patch(`/api/bookings/${bID}`).send({ contact_name: 'x' })).status).toBe(400);
  });

  it('requires login', async () => {
    expect((await request(ctx.app).patch(`/api/bookings/${bID}`).send({ n_people: 3 })).status).toBe(401);
  });

  // [BUG] Team decision: the destination slot of a move must respect the same 2-hour
  // booking window as a new booking (MH-01). PATCH does not check it, so a hiker can move
  // a booking into a slot that starts in a few minutes or has already started. Fails until fixed.
  it('[BUG] refuses to move a booking into a slot that starts in less than 2 hours', async () => {
    const soon = addSlot(ctx, '2026-12-01 09:59', '2026-12-01 11:00', { 1: 4 }); // in 1h59
    expect((await marco.patch(`/api/bookings/${bID}`).send({ tsID: soon })).status).toBe(409);
  });

  it('moves a booking into a slot that starts in exactly 2 hours', async () => {
    const later = addSlot(ctx, '2026-12-01 10:00', '2026-12-01 11:00', { 1: 4 });
    expect((await marco.patch(`/api/bookings/${bID}`).send({ tsID: later })).status).toBe(200);
  });
});
