import { transaction } from './transaction.js';

// builds the user DAO on top of an open database connection (makes it easy to inject a test db)
export function createUserDao(db) {
  // statement for inserting a user; :name, :email, ... are named parameters filled at run time
  const insert = db.prepare(`
    INSERT INTO users (name, email, phone, role, password, salt, must_change_password)
    VALUES (:name, :email, :phone, :role, :password, :salt, :must_change_password)`);
  
  // statement to look a user up by email (the column is NOCASE-unique, so the match ignores case)
  const byEmail = db.prepare('SELECT * FROM users WHERE email = ?');
  
  //  statement to look a user up by primary key
  const byId = db.prepare('SELECT * FROM users WHERE uID = ?');

  // DAO object (exposed to the rest of the server)
  return {
    // returns the new uID. Throws on constraint violations (e.g. duplicate email).
    // phone, password and salt default to NULL (profiles created by an employee have no password yet)
    insert({ name, email, phone = null, role, password = null, salt = null, mustChangePassword = false }) {
      // Runs the insert; SQLite returns the id of the new row in lastInsertRowid
      const { lastInsertRowid } = insert.run({
        name, email, phone, role, password, salt, must_change_password: mustChangePassword ? 1 : 0,
      });
      // lastInsertRowid may be a BigInt, so convert it to a plain number
      return Number(lastInsertRowid);
    },
    // returns the user row with that email, or undefined if there is none
    findByEmail: (email) => byEmail.get(email),
    // returns the user row with that uID, or undefined if there is none
    findById: (uID) => byId.get(uID),

    setPassword(uID, password, salt, mustChangePassword = false) {
      db.prepare('UPDATE users SET password = ?, salt = ?, must_change_password = ? WHERE uID = ?')
        .run(password, salt, mustChangePassword ? 1 : 0, uID);
    },

    // Password recovery tokens: only the hash of the token is ever stored.
    // Issuing a new token invalidates the unused ones of the same user.
    issueResetToken({ tokenHash, uID, expiresAt, now }) {
      db.prepare('UPDATE password_resets SET used_at = ? WHERE uID = ? AND used_at IS NULL').run(now, uID);
      db.prepare('INSERT INTO password_resets (token_hash, uID, expires_at) VALUES (?, ?, ?)')
        .run(tokenHash, uID, expiresAt);
    },
    // Marks the token as used and returns its uID, or undefined if it is unknown, used or expired.
    // One single UPDATE, so the same token can never be accepted twice.
    consumeResetToken(tokenHash, now) {
      return db.prepare(`
        UPDATE password_resets SET used_at = ?
        WHERE token_hash = ? AND used_at IS NULL AND expires_at > ?
        RETURNING uID`).get(now, tokenHash, now)?.uID;
    },
    // Used by the password reset to run the token check and the password update together.
    atomic: action => transaction(db, action),

    searchHikers(query) {
    const term = String(query ?? '').trim();
    if (!term) return [];

    const pattern = `%${term}%`;

    return db.prepare(`
    SELECT uID, name, email, phone, role
    FROM users
    WHERE role = 'hiker'
      AND (
            name LIKE ? COLLATE NOCASE
            OR email LIKE ? COLLATE NOCASE
            OR phone LIKE ?
          )
        ORDER BY name COLLATE NOCASE, uID
        LIMIT 20
      `).all(pattern, pattern, pattern);
    },
  };
}
