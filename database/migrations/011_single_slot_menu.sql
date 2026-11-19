PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
CREATE TABLE IF NOT EXISTS slot_menus (
  tsID INTEGER PRIMARY KEY REFERENCES timeslots(tsID) ON DELETE CASCADE,
  menu TEXT NOT NULL CHECK (length(trim(menu)) > 0)
) STRICT;

INSERT INTO slot_menus (tsID, menu)
SELECT tsID, group_concat(entry, char(10))
FROM (
  SELECT tsID, name || ': ' || description AS entry
  FROM menus
  ORDER BY tsID, mID
)
GROUP BY tsID
ON CONFLICT(tsID) DO NOTHING;

COMMIT;