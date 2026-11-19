// Starts the API inside the Docker container. On the first start it creates the
// database from database/schema.sql + database/seed.sql; later starts reuse it.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { DateTime } from 'luxon';
import { HUT_ZONE } from '../domain/time.js';
const databaseDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../database');
const file = process.env.DB_PATH ?? '/data/mountain_hut.db';
if (!fs.existsSync(file)) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const db = new DatabaseSync(file);
  db.exec(fs.readFileSync(path.join(databaseDir, 'schema.sql'), 'utf8'));
  db.exec('PRAGMA foreign_keys = ON');
  db.exec(fs.readFileSync(path.join(databaseDir, 'seed.sql'), 'utf8'));

  // The seed slots are in the past: add a few future slots, so the system can be tried at once.
  // The slot three days ahead is more than 48 hours away, so its bookings can still be changed (MH-06).
  const today = DateTime.now().setZone(HUT_ZONE).startOf('day');
  const futureSlots = [
    { day: 1, start: '12:00', end: '13:00', tables: [4, 4, 6] },
    { day: 1, start: '19:00', end: '20:30', tables: [2, 4, 6, 8] },
    { day: 3, start: '12:00', end: '13:00', tables: [4, 4, 6] },
  ];
  const insertSlot = db.prepare('INSERT INTO timeslots (start_time, end_time) VALUES (?, ?)');
  const insertTable = db.prepare('INSERT INTO slot_tables (tsID, table_no, seats) VALUES (?, ?, ?)');
  for (const slot of futureSlots) {
    const date = today.plus({ days: slot.day }).toISODate();
    const tsID = Number(insertSlot.run(`${date} ${slot.start}`, `${date} ${slot.end}`).lastInsertRowid);
    slot.tables.forEach((seats, index) => insertTable.run(tsID, index + 1, seats));
  }

  db.close();
  console.log(`Database created: ${file}`);
}
process.env.DB_PATH = file;
await import('../index.js');