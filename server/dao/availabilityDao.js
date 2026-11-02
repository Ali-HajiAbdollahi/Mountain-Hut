export function createAvailabilityDao(db) {
  const findSlot = db.prepare(`
    SELECT tsID, start_time, end_time
    FROM timeslots
    WHERE start_time = ?
  `);

  const findTables = db.prepare(`
    SELECT
      st.table_no,
      st.seats AS capacity,
      COALESCE(SUM(bt.seats), 0) AS bookedSeats
    FROM slot_tables AS st
    LEFT JOIN booking_tables AS bt
      ON bt.tsID = st.tsID
      AND bt.table_no = st.table_no
    WHERE st.tsID = ?
    GROUP BY st.tsID, st.table_no, st.seats
    ORDER BY st.table_no
  `);

  return {
    findByStartTime(startTime) {
      const slot = findSlot.get(startTime);

      // 找不到开始时间完全相同的时段
      if (!slot) return null;

      const tables = findTables.all(slot.tsID).map(table => ({
        ...table,
        freeSeats: table.capacity - table.bookedSeats,
      }));

      return { ...slot, tables };
    },
  };
}