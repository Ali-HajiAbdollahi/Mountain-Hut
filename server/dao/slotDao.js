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
  const dao = {
    atomic: action => transaction(db, action),
    find: id => slot.get(id),
    tables: id => tables.all(id),
    sameInterval: (a,b) => db.prepare(
      'SELECT tsID FROM timeslots WHERE start_time=? AND end_time=?').get(a,b),
    list: date => db.prepare(`
      SELECT s.tsID, sm.menu
      FROM timeslots AS s
      LEFT JOIN slot_menus AS sm ON sm.tsID = s.tsID
      WHERE substr(s.start_time, 1, 10) = ?
      ORDER BY s.start_time, s.tsID
    `).all(date),
    // Slots starting in [from, to), e.g. a week; times are 'YYYY-MM-DD HH:MM' strings.
    listRange: (from,to) => db.prepare(`SELECT tsID,start_time,end_time FROM timeslots
      WHERE start_time>=? AND start_time<? ORDER BY start_time,tsID`).all(from,to),
    saveSlotMenu(tsID, menu) {
      return db.prepare(`
        INSERT INTO slot_menus (tsID, menu)
        SELECT tsID, ? FROM timeslots WHERE tsID = ?
        ON CONFLICT(tsID) DO UPDATE SET menu = excluded.menu
        RETURNING tsID, menu
      `).get(menu, tsID) ?? null;
    },
    insert(a,b) { return Number(insert.run(a,b).lastInsertRowid); },
    insertTables(id, rows) {
      for (const t of rows) insertTable.run(id,t.table_no,t.seats);
    },

    // MH-135: copies the table layout of each source slot into a new slot at the
    // destination times supplied by the service: [{ sourceTsID, start_time, end_time }].
    // Only table numbers and capacities are copied, so the new slots have no bookings.
    // All-or-nothing: any failing insert (e.g. an existing slot) rolls back the whole
    // copy and the error propagates. Returns the new tsIDs, in the order of the input.
    copyWeek: copies => dao.atomic(() => copies.map(({ sourceTsID, start_time, end_time }) => {
      const id = dao.insert(start_time, end_time);
      dao.insertTables(id, dao.tables(sourceTsID).map(({ table_no, seats }) => ({ table_no, seats })));
      return id;
    })),
  };
  return dao;
}
