import { transaction } from './transaction.js';

export function createHikeDao(db) {
  const insertHike = db.prepare(`
    INSERT INTO hikes
      (uID, destination, route, departure_time, expected_return)
    VALUES (?, ?, ?, ?, ?)
  `);
  const insertWaypoint = db.prepare(`
    INSERT INTO hike_waypoints (hID, position, name)
    VALUES (?, ?, ?)
  `);

  return {
    atomic: action => transaction(db, action),

    insert({ uID, destination, route, departure_time, expected_return }) {
      return Number(insertHike.run(
        uID,
        destination,
        route,
        departure_time,
        expected_return,
      ).lastInsertRowid);
    },

    addWaypoints(hID, waypoints) {
      waypoints.forEach((waypoint, index) => {
        insertWaypoint.run(hID, index + 1, waypoint.name);
      });
    },

    find(hID) {
      const hike = db.prepare('SELECT * FROM hikes WHERE hID = ?').get(hID);
      if (!hike) return undefined;

      const waypoints = db.prepare(`
        SELECT position, name
        FROM hike_waypoints
        WHERE hID = ?
        ORDER BY position
      `).all(hID);

      return { ...hike, waypoints };
    },
  };
}
