import { ConflictError } from '../errors.js';
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
  const menuForSlot = db.prepare('SELECT menu FROM slot_menus WHERE tsID = ?');
  const dao = {
    atomic: action => transaction(db, action),
    find: id => slot.get(id),
    menu: id => menuForSlot.get(id)?.menu ?? null,
    tables: id => tables.all(id),
    overlaps: (a,b) => db.prepare(
      'SELECT tsID FROM timeslots WHERE start_time < ? AND end_time > ? LIMIT 1').get(b,a),
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
    recentMenus(before) {
      return db.prepare(`
        WITH ranked AS (
          SELECT s.tsID, s.start_time, s.end_time, m.menu,
                 ROW_NUMBER() OVER (
                   PARTITION BY m.menu ORDER BY s.start_time DESC, s.tsID DESC
                 ) AS rank_no
          FROM slot_menus m JOIN timeslots s ON s.tsID = m.tsID
          WHERE s.start_time < ?
        )
        SELECT tsID, start_time, end_time, menu FROM ranked WHERE rank_no = 1
        ORDER BY start_time DESC, tsID DESC LIMIT 20
      `).all(before);
    },
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

    targetHasBookings(from, to) {
      return Boolean(db.prepare(`
        SELECT 1 FROM bookings b JOIN timeslots s ON s.tsID = b.tsID
        WHERE s.start_time >= ? AND s.start_time < ? LIMIT 1
      `).get(from, to));
    },
    deleteWeek(from, to) {
      return Number(db.prepare(
        'DELETE FROM timeslots WHERE start_time >= ? AND start_time < ?'
      ).run(from, to).changes);
    },
    // The service owns the transaction covering source reads and replacement.
    copyWeek(copies) {
      return copies.map(({ sourceTsID, start_time, end_time }) => {
        if (dao.overlaps(start_time, end_time)) throw new ConflictError('Slot overlaps an existing slot');
        const id = dao.insert(start_time, end_time);
        dao.insertTables(id, dao.tables(sourceTsID).map(({ table_no, seats }) => ({ table_no, seats })));
        return id;
      });
    },
  };
  return dao;
}