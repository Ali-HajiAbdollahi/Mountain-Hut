// MH-20 Register a hike — integration tests (HTTP API + in-memory SQLite)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createTestContext, freezeTime, addHiker, addEmployee, loginAs } from '../helpers/app.js';

let ctx, marco, marcoUser;

const hike = {
  destination: 'Chiaretto Lake',
  route: 'Via the east ridge',
  departure_time: '2026-12-01 09:00',
  expected_return: '2026-12-01 17:30',
};

const register = (body, agent = marco) => agent.post('/api/hikes').send(body);
const hikesInDb = () => ctx.db.prepare('SELECT COUNT(*) AS n FROM hikes').get().n;
const waypointsInDb = () => ctx.db.prepare('SELECT COUNT(*) AS n FROM hike_waypoints').get().n;

beforeEach(async () => {
  freezeTime(); // 1 Dec 2026, 08:00 Europe/Rome
  ctx = createTestContext();
  marcoUser = addHiker(ctx);
  addEmployee(ctx);
  marco = await loginAs(ctx, 'marco@mail.it');
});
afterEach(() => {
  vi.restoreAllMocks();
  vi.useRealTimers();
  ctx.db.close();
});

describe('POST /api/hikes', () => {
  it('registers the planned hike of the logged-in hiker, with its waypoints in order', async () => {
    const res = await register({ ...hike, waypoints: [{ name: 'Vizo Mozzo' }, { name: 'Old Bridge' }] });

    expect(res.status).toBe(201);
    expect(res.body.hike).toMatchObject({
      uID: marcoUser.uID,
      ...hike,
      returned_at: null,
      waypoints: [
        { position: 1, name: 'Vizo Mozzo' },
        { position: 2, name: 'Old Bridge' },
      ],
    });
    expect(res.body.hike.hID).toEqual(expect.any(Number));
    expect(res.body.hike.created_at).toEqual(expect.any(String));
  });

  it('stores the hike in the database', async () => {
    const { hID } = (await register({ ...hike, waypoints: [{ name: 'Vizo Mozzo' }] })).body.hike;
    expect(ctx.db.prepare('SELECT uID, destination, route FROM hikes WHERE hID = ?').get(hID))
      .toEqual({ uID: marcoUser.uID, destination: 'Chiaretto Lake', route: 'Via the east ridge' });
    expect(ctx.db.prepare('SELECT position, name FROM hike_waypoints WHERE hID = ?').all(hID))
      .toEqual([{ position: 1, name: 'Vizo Mozzo' }]);
  });

  it('works without waypoints', async () => {
    const res = await register(hike);
    expect(res.status).toBe(201);
    expect(res.body.hike.waypoints).toEqual([]);
  });

  it('accepts a return on the following day', async () => {
    const res = await register({ ...hike, expected_return: '2026-12-02 12:00' });
    expect(res.status).toBe(201);
    expect(res.body.hike.expected_return).toBe('2026-12-02 12:00');
  });

  it('lets a hiker register several hikes', async () => {
    await register(hike);
    await register({ ...hike, destination: 'Vizo Mozzo', departure_time: '2026-12-03 07:00',
      expected_return: '2026-12-03 15:00' });
    expect(hikesInDb()).toBe(2);
  });

  it('takes the owner from the session: a uID in the body is rejected', async () => {
    const sara = addHiker(ctx, { name: 'Sara Verdi', email: 'sara@mail.it', phone: '3339998888' });
    const res = await register({ ...hike, uID: sara.uID });
    expect(res.status).toBe(400);
    expect(hikesInDb()).toBe(0);
  });

  it.each([
    ['missing destination', { destination: undefined }],
    ['blank route', { route: '   ' }],
    ['wrong time format', { departure_time: '2026-12-01T09:00' }],
    ['departure in the past', { departure_time: '2026-12-01 07:00' }],
    ['return before departure', { expected_return: '2026-12-01 08:30' }],
    ['return equal to departure', { expected_return: '2026-12-01 09:00' }],
    ['waypoints not a list', { waypoints: 'Vizo Mozzo' }],
    ['waypoint without a name', { waypoints: [{ name: '' }] }],
    ['unknown field', { difficulty: 'hard' }],
  ])('rejects invalid data (%s) with 400 and saves nothing', async (_, change) => {
    const res = await register({ ...hike, ...change });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(hikesInDb()).toBe(0);
  });

  it('saves nothing when a waypoint cannot be stored (one transaction)', async () => {
    vi.spyOn(ctx.hikeDao, 'addWaypoints').mockImplementation(() => {
      throw new Error('disk failure');
    });
    const res = await register({ ...hike, waypoints: [{ name: 'Vizo Mozzo' }] });
    expect(res.status).toBe(500);
    expect(hikesInDb()).toBe(0);
    expect(waypointsInDb()).toBe(0);
  });

  it('requires a login (401)', async () => {
    const res = await request(ctx.app).post('/api/hikes').send(hike);
    expect(res.status).toBe(401);
    expect(hikesInDb()).toBe(0);
  });

  it('is reserved to hikers: an employee gets 403', async () => {
    const elena = await loginAs(ctx, 'elena@hut.it');
    const res = await register(hike, elena);
    expect(res.status).toBe(403);
    expect(hikesInDb()).toBe(0);
  });

  it('the registered hike appears among the active hikes once it has started (MH-21)', async () => {
    await register({ ...hike, waypoints: [{ name: 'Vizo Mozzo' }] });
    const elena = await loginAs(ctx, 'elena@hut.it');
    expect((await elena.get('/api/hikes/active')).body).toEqual([]);

    vi.setSystemTime(new Date('2026-12-01T08:00:00Z')); // 09:00 in Rome, departure time
    expect((await elena.get('/api/hikes/active')).body).toEqual([expect.objectContaining({
      hiker_name: 'Marco Bianchi',
      destination: 'Chiaretto Lake',
      route: 'Via the east ridge',
      expected_return: '2026-12-01 17:30',
      waypoints: [{ position: 1, name: 'Vizo Mozzo' }],
    })]);
  });
});
