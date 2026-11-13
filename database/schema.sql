-- Mountain Hut — SQLite schema
-- Remember: PRAGMA foreign_keys = ON must be run on EVERY connection.
PRAGMA foreign_keys = ON;
 
-- Registered users only (hikers with an account, and employees).
-- Temporary hikers (MH-07) are NOT stored here: they live only in bookings.
CREATE TABLE users (
  uID       INTEGER PRIMARY KEY,
  name      TEXT    NOT NULL,
  email     TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  phone     TEXT,
  role      TEXT    NOT NULL CHECK (role IN ('hiker', 'employee')),
  password  TEXT,                      -- hash; NULL = profile created by an employee (MH-07), login not yet enabled
  salt      TEXT
) STRICT;
 
-- Slots with flexible start and duration (MH-02). Dates in ISO 8601: 'YYYY-MM-DD HH:MM'.
CREATE TABLE timeslots (
  tsID        INTEGER PRIMARY KEY,
  start_time  TEXT NOT NULL,
  end_time    TEXT NOT NULL,
  CHECK (end_time > start_time),
  UNIQUE (start_time, end_time)
) STRICT;
 
CREATE TABLE slot_menus (
  tsID INTEGER PRIMARY KEY REFERENCES timeslots(tsID) ON DELETE CASCADE,
  menu TEXT NOT NULL CHECK (length(trim(menu)) > 0)
) STRICT;

-- Table layout specific to each slot (no fixed set, MH-02).
-- Slot capacity = SUM(seats).
CREATE TABLE slot_tables (
  tsID      INTEGER NOT NULL REFERENCES timeslots(tsID) ON DELETE CASCADE,
  table_no  INTEGER NOT NULL,
  seats     INTEGER NOT NULL CHECK (seats > 0),
  PRIMARY KEY (tsID, table_no)
) STRICT;
 
-- Menus offered in each slot (MH-10, shown to users in MH-11).
-- A slot can offer several menus; they are deleted together with the slot.
CREATE TABLE menus (
  mID          INTEGER PRIMARY KEY,
  tsID         INTEGER NOT NULL REFERENCES timeslots(tsID) ON DELETE CASCADE,
  name         TEXT    NOT NULL,             -- e.g. 'Menu of the day', 'Vegetarian menu'
  description  TEXT    NOT NULL,             -- dishes offered
  UNIQUE (tsID, name)                        -- also serves as the index on tsID
) STRICT;
 
-- uID NULL  => temporary hiker (entered by an employee, MH-07)
-- contact_* => booking contact, always present (prefilled from the profile if registered)
CREATE TABLE bookings (
  bID            INTEGER PRIMARY KEY,
  tsID           INTEGER NOT NULL REFERENCES timeslots(tsID),
  uID            INTEGER REFERENCES users(uID),
  contact_name   TEXT    NOT NULL,
  contact_phone  TEXT,
  n_people       INTEGER NOT NULL CHECK (n_people > 0),
  created_at     TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by     INTEGER REFERENCES users(uID),   -- employee, NULL if booked via the web
  UNIQUE (bID, tsID)                               -- needed as target of the composite FK below
) STRICT;
 
-- How many seats of which table each booking occupies 
-- (MH-01: party over several tables,
-- MH-04: partially occupied tables).
CREATE TABLE booking_tables (
  bID       INTEGER NOT NULL,
  tsID      INTEGER NOT NULL,
  table_no  INTEGER NOT NULL,
  seats     INTEGER NOT NULL CHECK (seats > 0),
  PRIMARY KEY (bID, table_no),
  -- ensures tsID matches the booking's own slot
  FOREIGN KEY (bID, tsID)       REFERENCES bookings(bID, tsID) ON DELETE CASCADE,
  -- ensures the table exists in that slot
  FOREIGN KEY (tsID, table_no)  REFERENCES slot_tables(tsID, table_no)
) STRICT;
 
-- Requirements for subgroups of the party (MH-05).
CREATE TABLE booking_requirements (
  rID          INTEGER PRIMARY KEY,
  bID          INTEGER NOT NULL REFERENCES bookings(bID) ON DELETE CASCADE,
  n_people     INTEGER CHECK (n_people > 0),
  description  TEXT    NOT NULL,
  allergy      INTEGER NOT NULL DEFAULT 0 CHECK (allergy IN (0, 1))
) STRICT;
 
-- Hikes registered by hikers before departure (MH-20), monitored by employees (MH-21).
-- returned_at NULL => hiker not back yet: the hike is active once departure_time has passed,
-- and overdue once expected_return has passed.
CREATE TABLE hikes (
  hID              INTEGER PRIMARY KEY,
  uID              INTEGER NOT NULL REFERENCES users(uID),
  destination      TEXT    NOT NULL,
  route            TEXT    NOT NULL,         -- e.g. 'via the Chiaretto lake'
  departure_time   TEXT    NOT NULL,         -- 'YYYY-MM-DD HH:MM', like timeslots
  expected_return  TEXT    NOT NULL,
  returned_at      TEXT,
  created_at       TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (expected_return > departure_time),
  CHECK (returned_at IS NULL OR returned_at >= departure_time)
) STRICT;
 
-- Optional intermediate passage points of a hike, in order.
CREATE TABLE hike_waypoints (
  hID       INTEGER NOT NULL REFERENCES hikes(hID) ON DELETE CASCADE,
  position  INTEGER NOT NULL CHECK (position > 0),
  name      TEXT    NOT NULL,
  PRIMARY KEY (hID, position)
) STRICT;
 
-- Prevents assigning a table more seats than it has.
CREATE TRIGGER booking_tables_capacity_ins
BEFORE INSERT ON booking_tables
BEGIN
  SELECT RAISE(ABORT, 'table capacity exceeded')
  WHERE NEW.seats + COALESCE((SELECT SUM(seats) FROM booking_tables
                              WHERE tsID = NEW.tsID AND table_no = NEW.table_no), 0)
        > (SELECT seats FROM slot_tables
           WHERE tsID = NEW.tsID AND table_no = NEW.table_no);
END;
 
CREATE TRIGGER booking_tables_capacity_upd
BEFORE UPDATE OF seats, tsID, table_no ON booking_tables
BEGIN
  SELECT RAISE(ABORT, 'table capacity exceeded')
  WHERE NEW.seats + COALESCE((SELECT SUM(seats) FROM booking_tables
                              WHERE tsID = NEW.tsID AND table_no = NEW.table_no
                                AND NOT (bID = OLD.bID AND table_no = OLD.table_no)), 0)
        > (SELECT seats FROM slot_tables
           WHERE tsID = NEW.tsID AND table_no = NEW.table_no);
END;
 
-- Prevents reducing a table's seats below the already booked ones (MH-02).
CREATE TRIGGER slot_tables_capacity_upd
BEFORE UPDATE OF seats ON slot_tables
BEGIN
  SELECT RAISE(ABORT, 'table capacity below booked seats')
  WHERE NEW.seats < COALESCE((SELECT SUM(seats) FROM booking_tables
                              WHERE tsID = OLD.tsID AND table_no = OLD.table_no), 0);
END;

CREATE INDEX idx_bookings_ts        ON bookings(tsID);
CREATE INDEX idx_bookings_user      ON bookings(uID);
CREATE INDEX idx_booking_tables_tab ON booking_tables(tsID, table_no);
CREATE INDEX idx_requirements_bk    ON booking_requirements(bID);
CREATE INDEX idx_users_name         ON users(name);
CREATE INDEX idx_users_phone        ON users(phone);
CREATE INDEX idx_hikes_user         ON hikes(uID);
-- Only hikes not yet closed, ordered by expected return (MH-21).
CREATE INDEX idx_hikes_active       ON hikes(expected_return) WHERE returned_at IS NULL;
