PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;

CREATE TABLE IF NOT EXISTS hikes (
  hID              INTEGER PRIMARY KEY,
  uID              INTEGER NOT NULL REFERENCES users(uID),
  destination      TEXT    NOT NULL,
  route            TEXT    NOT NULL,
  departure_time   TEXT    NOT NULL,
  expected_return  TEXT    NOT NULL,
  returned_at      TEXT,
  created_at       TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (expected_return > departure_time),
  CHECK (returned_at IS NULL OR returned_at >= departure_time)
) STRICT;

CREATE TABLE IF NOT EXISTS hike_waypoints (
  hID       INTEGER NOT NULL REFERENCES hikes(hID) ON DELETE CASCADE,
  position  INTEGER NOT NULL CHECK (position > 0),
  name      TEXT    NOT NULL,
  PRIMARY KEY (hID, position)
) STRICT;

CREATE INDEX IF NOT EXISTS idx_hikes_user
  ON hikes(uID);

CREATE INDEX IF NOT EXISTS idx_hikes_active
  ON hikes(expected_return)
  WHERE returned_at IS NULL;

COMMIT;
