PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;

-- The named menus of 010 were merged into slot_menus by 011 (MH-110):
-- the old table is no longer read or written.
DROP TABLE IF EXISTS menus;

COMMIT;
