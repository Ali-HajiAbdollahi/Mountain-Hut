// builds the user DAO on top of an open database connection (makes it easy to inject a test db)
export function createUserDao(db) {
  // statement for inserting a user; :name, :email, ... are named parameters filled at run time
  const insert = db.prepare(`
    INSERT INTO users (name, email, phone, role, password, salt)
    VALUES (:name, :email, :phone, :role, :password, :salt)`);
  
  // statement to look a user up by email (the column is NOCASE-unique, so the match ignores case)
  const byEmail = db.prepare('SELECT * FROM users WHERE email = ?');
  
  //  statement to look a user up by primary key
  const byId = db.prepare('SELECT * FROM users WHERE uID = ?');

  // DAO object (exposed to the rest of the server)
  return {
    // returns the new uID. Throws on constraint violations (e.g. duplicate email).
    // phone, password and salt default to NULL (profiles created by an employee have no password yet)
    insert({ name, email, phone = null, role, password = null, salt = null }) {
      // Runs the insert; SQLite returns the id of the new row in lastInsertRowid
      const { lastInsertRowid } = insert.run({ name, email, phone, role, password, salt });
      // lastInsertRowid may be a BigInt, so convert it to a plain number
      return Number(lastInsertRowid);
    },
    // returns the user row with that email, or undefined if there is none
    findByEmail: (email) => byEmail.get(email),
    // returns the user row with that uID, or undefined if there is none
    findById: (uID) => byId.get(uID),
  };
}
