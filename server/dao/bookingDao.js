import { transaction } from './transaction.js';

export function createBookingDao(db) {
  return {
    atomic: action=>transaction(db,action),
    duplicate: (uID,tsID)=>db.prepare('SELECT bID FROM bookings WHERE uID=? AND tsID=?').get(uID,tsID),
    insert({
      tsID,
      uID = null,
      contact_name,
      contact_phone = null,
      n_people,
      created_by = null,
    }) {
      return Number(db.prepare(`INSERT INTO bookings
        (tsID,uID,contact_name,contact_phone,n_people,created_by) VALUES (?,?,?,?,?,?)`)
        .run(tsID,uID,contact_name,contact_phone,n_people,created_by).lastInsertRowid);
    },
    assign(bID,tsID,tables) {
      const q=db.prepare('INSERT INTO booking_tables(bID,tsID,table_no,seats) VALUES (?,?,?,?)');
      for (const t of tables) q.run(bID,tsID,t.table_no,t.seats);
    },
    addRequirements(bID,requirements) {
      const q=db.prepare(`INSERT INTO booking_requirements(bID,n_people,description,allergy) VALUES (?,?,?,?)`);
      for (const r of requirements) q.run(bID,r.n_people,r.description,Number(r.allergy));
    },
    find(bID) {
      const row=db.prepare(`SELECT b.*,s.start_time,s.end_time FROM bookings b
        JOIN timeslots s ON s.tsID=b.tsID WHERE b.bID=?`).get(bID);
      if (!row) return undefined;
      const tables=db.prepare('SELECT table_no,seats FROM booking_tables WHERE bID=? ORDER BY table_no').all(bID);
      const requirements=db.prepare(`SELECT rID,n_people,description,allergy
        FROM booking_requirements WHERE bID=? ORDER BY rID`).all(bID)
        .map(r=>({...r,allergy:Boolean(r.allergy)}));
      return {...row,reference:`MH-${row.bID}`,tables,requirements};
    },
    listForUser(uID) {
      return db.prepare(`SELECT b.bID FROM bookings b JOIN timeslots s ON s.tsID=b.tsID
        WHERE b.uID=? ORDER BY s.start_time,b.bID`).all(uID).map(r=>this.find(r.bID));
    },

    removeAssignments(bID) {
      db.prepare('DELETE FROM booking_tables WHERE bID = ?').run(bID);
    },

    update(bID, { tsID, n_people }) {
      db.prepare(`
       UPDATE bookings
       SET tsID = ?, n_people = ?
       WHERE bID = ?
       `).run(tsID, n_people, bID);
    },

    replaceRequirements(bID, requirements) {
      db.prepare('DELETE FROM booking_requirements WHERE bID = ?').run(bID);

      const insert = db.prepare(`
        INSERT INTO booking_requirements
          (bID, n_people, description, allergy)
           VALUES (?, ?, ?, ?)
           `);

        for (const requirement of requirements) {
          insert.run(
            bID,
            requirement.n_people,
            requirement.description,
            Number(requirement.allergy),
          );
        }    
     },

  };
}
