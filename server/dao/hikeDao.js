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
  const activeHikes = db.prepare(`
    SELECT
      h.hID,
      u.name AS hiker_name,
      h.destination,
      h.route,
      h.expected_return
    FROM hikes AS h
    JOIN users AS u ON u.uID = h.uID
    WHERE h.departure_time <= ?
      AND h.returned_at IS NULL
    ORDER BY h.expected_return, h.hID
  `);
  const waypointsForHike = db.prepare(`
    SELECT position, name
    FROM hike_waypoints
    WHERE hID = ?
    ORDER BY position
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

    listActive(now) {
      return activeHikes.all(now).map(hike => ({
        ...hike,
        waypoints: waypointsForHike.all(hike.hID),
      }));
    },
  };
}
