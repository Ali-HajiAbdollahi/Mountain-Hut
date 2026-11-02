import { transaction } from './transaction.js';

export function createSlotDao(db) {
  const slot = db.prepare('SELECT * FROM timeslots WHERE tsID = ?');
  const tables = db.prepare(`
    SELECT st.table_no, st.seats,
           st.seats - COALESCE(SUM(bt.seats), 0) AS free_seats
    FROM slot_tables st LEFT JOIN booking_tables bt
      ON bt.tsID = st.tsID AND bt.table_no = st.table_no
    WHERE st.tsID = ? GROUP BY st.table_no, st.seats ORDER BY st.table_no`);
  const insert = db.prepare('INSERT INTO timeslots(start_time,end_time) VALUES (?,?)');
  const insertTable = db.prepare('INSERT INTO slot_tables(tsID,table_no,seats) VALUES (?,?,?)');
  return {
    atomic: action => transaction(db, action),
    find: id => slot.get(id),
    tables: id => tables.all(id),
    sameInterval: (a,b) => db.prepare(
      'SELECT tsID FROM timeslots WHERE start_time=? AND end_time=?').get(a,b),
    list: date => db.prepare(`SELECT tsID FROM timeslots
      WHERE substr(start_time,1,10)=? ORDER BY start_time,tsID`).all(date),
    insert(a,b) { return Number(insert.run(a,b).lastInsertRowid); },
    insertTables(id, rows) {
      for (const t of rows) insertTable.run(id,t.table_no,t.seats);
    },
  };
}