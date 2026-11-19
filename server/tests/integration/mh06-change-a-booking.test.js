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

  describe('party size changes', () => {
    // Tables 1 (4 seats) and 2 (6 seats). Table 1 is taken while Marco books, so he sits at
    // table 2; once it is free, a fresh allocation would prefer table 1 (smaller).
    let dinner, dinnerBID;
    beforeEach(async () => {
      dinner = addSlot(ctx, '2026-12-06 19:00', '2026-12-06 20:00', { 1: 4, 2: 6 });
      const sara = await loginAs(ctx, 'sara@mail.it');
      const blocker = await sara.post('/api/bookings').send({ tsID: dinner, n_people: 4 });
      dinnerBID = (await marco.post('/api/bookings').send({ tsID: dinner, n_people: 2 })).body.booking.bID;
      await sara.delete(`/api/bookings/${blocker.body.booking.bID}`);
      expect(seatsOf(ctx, dinnerBID)).toEqual({ 2: 2 });
    });

    it('treats the new party size as a new booking, even when it still fits at the old tables', async () => {
      const res = await marco.patch(`/api/bookings/${dinnerBID}`).send({ n_people: 3 });
      expect(res.status).toBe(200);
      expect(res.body.booking.n_people).toBe(3);
      expect(seatsOf(ctx, dinnerBID)).toEqual({ 1: 3 });
    });

    it('reassigns the tables with the MH-01 rules when the party no longer fits at them', async () => {
      const res = await marco.patch(`/api/bookings/${dinnerBID}`).send({ n_people: 7 });
      expect(res.status).toBe(200);
      expect(res.body.booking.n_people).toBe(7);
      expect(seatsOf(ctx, dinnerBID)).toEqual({ 1: 4, 2: 3 });
    });

    it('refuses a party that fits nowhere and leaves the booking as it was', async () => {
      const res = await marco.patch(`/api/bookings/${dinnerBID}`).send({ n_people: 11 });
      expect(res.status).toBe(409);
      expect(seatsOf(ctx, dinnerBID)).toEqual({ 2: 2 });
      expect((await marco.get(`/api/bookings/${dinnerBID}`)).body.n_people).toBe(2);
      const slot = await request(ctx.app).get(`/api/timeslots/${dinner}`);
      expect(slot.body.free_seats).toBe(8);
    });
  });

  describe('email notification', () => {
    it('sends the updated booking to the hiker on every successful change', async () => {
      const before = ctx.mail.sent.length;
      const size = await marco.patch(`/api/bookings/${bID}`).send({ n_people: 3 });
      const move = await marco.patch(`/api/bookings/${bID}`).send({ tsID: secondLunch });
      const requirements = await marco.patch(`/api/bookings/${bID}`)
        .send({ requirements: [{ description: 'nut allergy', allergy: true, n_people: 1 }] });

      expect(size.body.notification).toMatchObject({ status: 'accepted' });
      expect(move.body.notification).toMatchObject({ status: 'accepted' });
      expect(requirements.body.notification).toMatchObject({ status: 'accepted' });
      const sent = ctx.mail.sent.slice(before);
      expect(sent).toHaveLength(3);
      expect(sent.every(mail => mail.to === 'marco@mail.it')).toBe(true);
      expect(sent[0].text).toContain('Party size: 3');
      expect(sent[1].text).toContain('Date: 2026-12-05');
      expect(sent[1].text).toContain('Time slot: 13:00 - 14:00');
      expect(sent[2].text).toContain('ALLERGY — People: 1: nut allergy');
    });

    it('uses the update template, not the booking confirmation one', async () => {
      const before = ctx.mail.sent.length;
      await marco.patch(`/api/bookings/${bID}`).send({ n_people: 5 });
      const [mail] = ctx.mail.sent.slice(before);

      expect(mail.subject).toBe(`Mountain Hut: Your Booking has been Updated (Ref: MH-${bID})`);
      expect(mail.text).toContain('Your reservation has been successfully updated. Here are your new booking details:');
      expect(mail.text).toContain('Date: 2026-12-05');
      expect(mail.text).toContain('Time slot: 12:00 - 13:00');
      expect(mail.text).toContain('Party size: 5');
      expect(mail.text).toContain('Assigned tables: Table 3 (5 seats)');
      expect(mail.text).not.toContain('Booking confirmed');
      expect(mail.html).toContain('successfully updated');
    });

    it('lists every assigned table in the email', async () => {
      const before = ctx.mail.sent.length;
      await marco.patch(`/api/bookings/${bID}`).send({ n_people: 8 }); // 2 + 6
      expect(ctx.mail.sent[before].text).toContain('Assigned tables: Table 1 (2 seats), Table 3 (6 seats)');
    });

    it('sends nothing when the change is refused', async () => {
      const before = ctx.mail.sent.length;
      expect((await marco.patch(`/api/bookings/${bID}`).send({ n_people: 13 })).status).toBe(409);
      expect((await marco.patch(`/api/bookings/${bID}`).send({})).status).toBe(400);
      expect(ctx.mail.sent).toHaveLength(before);
    });

    it('keeps the change when the email is not delivered', async () => {
      ctx.mail.send = async () => ({ status: 'failed' });
      const res = await marco.patch(`/api/bookings/${bID}`).send({ n_people: 5 });
      expect(res.status).toBe(200);
      expect(res.body.notification).toEqual({ status: 'failed' });
      expect(seatsOf(ctx, bID)).toEqual({ 3: 5 });
    });

    it('keeps the change when sending the email throws', async () => {
      ctx.mail.send = async () => { throw new Error('smtp down'); };
      vi.spyOn(console, 'error').mockImplementation(() => {});
      const res = await marco.patch(`/api/bookings/${bID}`).send({ n_people: 5 });
      expect(res.status).toBe(200);
      expect(res.body.notification).toEqual({ status: 'failed' });
      expect((await marco.get(`/api/bookings/${bID}`)).body.n_people).toBe(5);
    });
  });

  // MH-06 rule (confirmed by the team): changes are allowed until 48 hours before
  // the booked meal, however old the booking is.
  it('allows changes to an old booking while the meal is more than 48 hours away', async () => {
    setCreatedAt(bID, '2026-11-01 10:00:00'); // booked a month ago, meal on 5 Dec
    expect((await marco.patch(`/api/bookings/${bID}`).send({ n_people: 3 })).status).toBe(200);
  });

  it('refuses changes less than 48 hours before the meal', async () => {
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

  // Team decision: the destination slot of a move must respect the same 2-hour
  // booking window as a new booking (MH-01).
  it('refuses to move a booking into a slot that starts in less than 2 hours', async () => {
    const soon = addSlot(ctx, '2026-12-01 09:59', '2026-12-01 11:00', { 1: 4 }); // in 1h59
    expect((await marco.patch(`/api/bookings/${bID}`).send({ tsID: soon })).status).toBe(409);
  });

  it('moves a booking into a slot that starts in exactly 2 hours', async () => {
    const later = addSlot(ctx, '2026-12-01 10:00', '2026-12-01 11:00', { 1: 4 });
    expect((await marco.patch(`/api/bookings/${bID}`).send({ tsID: later })).status).toBe(200);
  });
});
