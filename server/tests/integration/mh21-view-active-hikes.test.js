// MH-21 View active hikes — API integration tests with in-memory SQLite and a fixed clock.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';
import {
  addEmployee,
  addHiker,
  createTestContext,
  freezeTime,
  loginAs,
} from '../helpers/app.js';

let ctx;
let employee;
let marco;
let sara;

beforeEach(async () => {
  freezeTime(new Date('2026-12-01T07:59:00Z')); // 1 Dec 2026, 08:59 Europe/Rome
  ctx = createTestContext();
  marco = addHiker(ctx);
  sara = addHiker(ctx, {
    name: 'Sara Verdi',
    email: 'sara@mail.it',
    phone: '3339998888',
  });
  addEmployee(ctx);
  employee = await loginAs(ctx, 'elena@hut.it');
});

afterEach(() => {
  vi.useRealTimers();
  ctx.db.close();
});

function addHike({
  uID,
  destination,
  route,
  departure_time,
  expected_return,
  returned_at = null,
  waypoints = [],
}) {
  const hID = Number(ctx.db.prepare(`
    INSERT INTO hikes
      (uID, destination, route, departure_time, expected_return, returned_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(
    uID,
    destination,
    route,
    departure_time,
    expected_return,
    returned_at,
  ).lastInsertRowid);

  const insertWaypoint = ctx.db.prepare(`
    INSERT INTO hike_waypoints (hID, position, name)
    VALUES (?, ?, ?)
  `);
  waypoints.forEach((name, index) => insertWaypoint.run(hID, index + 1, name));
  return hID;
}

describe('GET /api/hikes/active', () => {
  it('tracks hikes before departure, at departure, after expected return, and after a return is recorded', async () => {
    const atDepartureID = addHike({
      uID: marco.uID,
      destination: 'Shared Peak',
      route: 'East ridge',
      departure_time: '2026-12-01 09:00',
      expected_return: '2026-12-01 10:00',
      waypoints: ['Old Bridge', 'Vizo Mozzo'],
    });

    const overdueID = addHike({
      uID: sara.uID,
      destination: 'Shared Peak',
      route: 'Via the lake',
      departure_time: '2026-12-01 09:00',
      expected_return: '2026-12-01 10:00',
      waypoints: ['Chiaretto Lake'],
    });

    const beforeDeparture = await employee.get('/api/hikes/active');
    expect(beforeDeparture.status).toBe(200);
    expect(beforeDeparture.body).toEqual([]);

    vi.setSystemTime(new Date('2026-12-01T08:00:00Z')); // exactly 09:00 in Rome
    const atDeparture = await employee.get('/api/hikes/active');
    expect(atDeparture.status).toBe(200);
    expect(atDeparture.body).toHaveLength(2);
    expect(atDeparture.body).toEqual(expect.arrayContaining([
      expect.objectContaining({
        hID: atDepartureID,
        hiker_name: 'Marco Bianchi',
        destination: 'Shared Peak',
        route: 'East ridge',
        expected_return: '2026-12-01 10:00',
        waypoints: [
          { position: 1, name: 'Old Bridge' },
          { position: 2, name: 'Vizo Mozzo' },
        ],
      }),
      expect.objectContaining({
        hID: overdueID,
        hiker_name: 'Sara Verdi',
        destination: 'Shared Peak',
        route: 'Via the lake',
        expected_return: '2026-12-01 10:00',
        waypoints: [{ position: 1, name: 'Chiaretto Lake' }],
      }),
    ]));

    vi.setSystemTime(new Date('2026-12-01T09:01:00Z')); // 10:01, after expected return
    const afterExpectedReturn = await employee.get('/api/hikes/active');
    expect(afterExpectedReturn.status).toBe(200);
    expect(afterExpectedReturn.body).toHaveLength(2);

    ctx.db.prepare('UPDATE hikes SET returned_at = ? WHERE hID = ?')
      .run('2026-12-01 10:05', atDepartureID);
    const afterReturnRecorded = await employee.get('/api/hikes/active');
    expect(afterReturnRecorded.status).toBe(200);
    expect(afterReturnRecorded.body).toHaveLength(1);
    expect(afterReturnRecorded.body[0].hID).toBe(overdueID);

  });

  it('returns an empty array when there are no active hikes', async () => {
    const response = await employee.get('/api/hikes/active');

    expect(response.status).toBe(200);
    expect(response.body).toEqual([]);
  });

  it('rejects anonymous users and hikers', async () => {
    const anonymous = await request(ctx.app).get('/api/hikes/active');
    const hiker = await loginAs(ctx, 'marco@mail.it');
    const forbidden = await hiker.get('/api/hikes/active');

    expect(anonymous.status).toBe(401);
    expect(forbidden.status).toBe(403);
  });
});
