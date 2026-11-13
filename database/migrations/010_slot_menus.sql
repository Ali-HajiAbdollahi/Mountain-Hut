PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
CREATE TABLE IF NOT EXISTS menus (
  mID          INTEGER PRIMARY KEY,
  tsID         INTEGER NOT NULL REFERENCES timeslots(tsID) ON DELETE CASCADE,
  name         TEXT    NOT NULL,             -- e.g. 'Menu of the day', 'Vegetarian menu'
  description  TEXT    NOT NULL,             -- dishes offered
  UNIQUE (tsID, name)                        -- also serves as the index on tsID
) STRICT;
COMMIT;