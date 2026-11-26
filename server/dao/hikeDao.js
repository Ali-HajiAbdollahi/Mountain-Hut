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
  const openHikesOfOwner = db.prepare(`
    SELECT hID, destination, departure_time, expected_return
    FROM hikes
    WHERE uID = ?
      AND returned_at IS NULL
    ORDER BY departure_time, hID
  `);
  // A single UPDATE, so the first confirmation is never overwritten. The departure
  // condition keeps the CHECK (returned_at >= departure_time) from failing.
  const confirmOwnedReturn = db.prepare(`
    UPDATE hikes
    SET returned_at = ?
    WHERE hID = ?
      AND uID = ?
      AND returned_at IS NULL
      AND departure_time <= ?
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

    // The hikes of user uID not yet confirmed as completed (MH-71), the earliest departure first.
    // Hikes that have not started yet are included: departure_time tells them apart.
    listOpenByOwner(uID) {
      return openHikesOfOwner.all(uID);
    },

    // Records that the owner is back from hike hID (MH-71). returnedAt is 'YYYY-MM-DD HH:MM'
    // in hut time. Returns false, changing nothing, if the hike does not exist, belongs to
    // another user, is already confirmed or has not started yet at returnedAt.
    confirmReturn(hID, uID, returnedAt) {
      return confirmOwnedReturn.run(returnedAt, hID, uID, returnedAt).changes > 0;
    },
  };
}
