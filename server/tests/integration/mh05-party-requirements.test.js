// MH-05 Provide party requirements — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { createTestContext, freezeTime, addHiker, addSlot, loginAs } from '../helpers/app.js';

let ctx, lunch, marco;

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  addHiker(ctx);
  lunch = addSlot(ctx, '2026-12-01 12:00', '2026-12-01 13:00', { 1: 4, 2: 6 });
  marco = await loginAs(ctx, 'marco@mail.it');
});
afterEach(() => {
  vi.useRealTimers();
});

// The three requirements of the story example
const storyRequirements = [
  { allergy: true, description: '1 vegan, peanut allergy', n_people: 1 },
  { allergy: true, description: '1 shellfish allergy', n_people: 1 },
  { allergy: false, description: '2 vegetarians', n_people: 2 },
];

describe('requirements on POST /api/bookings', () => {
  it('stores a list of requirements, each with its own allergy flag and description', async () => {
    const res = await marco.post('/api/bookings').send({ tsID: lunch, n_people: 4, requirements: storyRequirements });
    expect(res.status).toBe(201);
    expect(res.body.booking.requirements).toMatchObject(storyRequirements);

    const rows = ctx.db.prepare('SELECT description, allergy FROM booking_requirements ORDER BY rID').all();
    expect(rows.map(r => r.allergy)).toEqual([1, 1, 0]);
  });

  it('works without requirements', async () => {
    const res = await marco.post('/api/bookings').send({ tsID: lunch, n_people: 2 });
    expect(res.body.booking.requirements).toEqual([]);
  });

  it('marks allergies in the confirmation email', async () => {
    await marco.post('/api/bookings').send({ tsID: lunch, n_people: 4, requirements: storyRequirements });
    const { text } = ctx.mail.sent[0];
    expect(text).toContain('ALLERGY — People: 1: 1 shellfish allergy');
    expect(text).toContain('People: 2: 2 vegetarians');
    expect(text).not.toContain('ALLERGY — People: 2: 2 vegetarians');
  });

  it('rejects an invalid requirement and saves neither the booking nor the requirements', async () => {
    const res = await marco.post('/api/bookings').send({
      tsID: lunch, n_people: 2, requirements: [{ description: 'vegan', allergy: 'no' }] });
    expect(res.status).toBe(400);
    expect(ctx.db.prepare('SELECT COUNT(*) AS n FROM bookings').get().n).toBe(0);
    expect(ctx.db.prepare('SELECT COUNT(*) AS n FROM booking_requirements').get().n).toBe(0);
  });

  it('rejects a requirement for more people than the party', async () => {
    const res = await marco.post('/api/bookings').send({
      tsID: lunch, n_people: 2, requirements: [{ description: 'vegan', allergy: false, n_people: 3 }] });
    expect(res.status).toBe(400);
  });

  it('returns the requirements in the booking details', async () => {
    const { body } = await marco.post('/api/bookings').send({ tsID: lunch, n_people: 4, requirements: storyRequirements });
    const res = await marco.get(`/api/bookings/${body.booking.bID}`);
    expect(res.body.requirements.map(r => r.allergy)).toEqual([true, true, false]);
  });
});
