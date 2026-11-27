PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;

-- MH-72: people taking part in a hike, in order. The hiker who registers the hike is a
-- member too, at position 1: the party size is the number of members.
CREATE TABLE IF NOT EXISTS hike_party_members (
  hID       INTEGER NOT NULL REFERENCES hikes(hID) ON DELETE CASCADE,
  position  INTEGER NOT NULL CHECK (position > 0),
  name      TEXT    NOT NULL CHECK (length(trim(name)) > 0),
  phone     TEXT    CHECK (phone IS NULL OR length(trim(phone)) > 0),
  PRIMARY KEY (hID, position)
) STRICT;

-- Hikes registered before MH-72 get their owner as the only member, so that every hike
-- has a party. Running the migration again adds nothing.
INSERT INTO hike_party_members (hID, position, name, phone)
SELECT h.hID, 1, u.name, NULLIF(trim(u.phone), '')
FROM hikes AS h
JOIN users AS u ON u.uID = h.uID
WHERE NOT EXISTS (
  SELECT 1 FROM hike_party_members AS m WHERE m.hID = h.hID
);

COMMIT;
