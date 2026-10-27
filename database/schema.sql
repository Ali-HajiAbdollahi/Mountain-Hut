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
 
-- Table layout specific to each slot (no fixed set, MH-02).
-- Slot capacity = SUM(seats).
CREATE TABLE slot_tables (
  tsID      INTEGER NOT NULL REFERENCES timeslots(tsID) ON DELETE CASCADE,
  table_no  INTEGER NOT NULL,
  seats     INTEGER NOT NULL CHECK (seats > 0),
  PRIMARY KEY (tsID, table_no)
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
