export function transaction(db, action) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = action(); // Synchronous only: never await inside this transaction.
    db.exec('COMMIT');
    return result;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}