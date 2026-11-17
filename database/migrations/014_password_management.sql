PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;

-- MH-07: accounts created by an employee get a random password that must be changed at the
-- next login. Existing accounts keep working unchanged.
ALTER TABLE users
  ADD COLUMN must_change_password INTEGER NOT NULL DEFAULT 0
  CHECK (must_change_password IN (0, 1));

-- MH-07: password recovery. Only the SHA-256 of the token is stored.
CREATE TABLE IF NOT EXISTS password_resets (
  token_hash  TEXT    PRIMARY KEY,
  uID         INTEGER NOT NULL REFERENCES users(uID) ON DELETE CASCADE,
  expires_at  TEXT    NOT NULL,
  used_at     TEXT
) STRICT;

CREATE INDEX IF NOT EXISTS idx_password_resets_user
  ON password_resets(uID);

COMMIT;
