// Shared setup for integration tests: in-memory database, app wiring and fixtures.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { vi } from 'vitest';
import request from 'supertest';
import { openDb } from '../../db.js';
import { createApp } from '../../app.js';
import { createBookingDao } from '../../dao/bookingDao.js';
import { createSlotDao } from '../../dao/slotDao.js';
import { createUserDao } from '../../dao/userDao.js';
import { createAuthService } from '../../services/authService.js';
import { createBookingService } from '../../services/bookingService.js';
import { createBookingChangeService } from '../../services/bookingChangeService.js';
import { createStaffBookingService } from '../../services/staffBookingService.js';
import { createHikeDao } from '../../dao/hikeDao.js';
import { createHikeService } from '../../services/hikeService.js';
import { createBookingRouter } from '../../routes/bookingRoutes.js';
import { createStaffBookingRouter } from '../../routes/staffBookingRoutes.js';
import { createHikeRouter } from '../../routes/hikeRoutes.js';

const SCHEMA = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../../database/schema.sql');

export const PASSWORD = 'password123';

// "Now" for every integration test: 1 Dec 2026, 08:00 in Europe/Rome
export const NOW = new Date('2026-12-01T07:00:00Z');

// Only Date is faked, so Express and supertest timers keep working
export function freezeTime(at = NOW) {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(at);
}

// Records emails instead of sending them
export function createFakeMail() {
  const sent = [];
  return {
    sent,
    async send(to, message) {
      sent.push({ to, ...message });
      return { status: 'accepted', messageId: `test-${sent.length}` };
    },
  };
}

// Same wiring as index.js, but on a fresh in-memory database
export function createTestContext() {
  const db = openDb(':memory:');
  db.exec(fs.readFileSync(SCHEMA, 'utf8'));
  const mail = createFakeMail();
  const bookingDao = createBookingDao(db);
  const slotDao = createSlotDao(db);
  const users = createUserDao(db);
  const auth = createAuthService(users);
  const bookingRouter = createBookingRouter(
    createBookingService(bookingDao, slotDao),
    mail,
    createBookingChangeService(bookingDao, slotDao),
  );
  const staffBookingRouter = createStaffBookingRouter(
    createStaffBookingService(users, bookingDao, slotDao, auth),
  );
  const hikeDao = createHikeDao(db);
  const hikeRouter = createHikeRouter(createHikeService(hikeDao));
  const app = createApp(db, { bookingRouter, staffBookingRouter, hikeRouter });
  return { db, app, mail, auth, hikeDao };
}

// Registers a hiker through the real auth service and returns the public profile
export function addHiker(ctx, { name = 'Marco Bianchi', email = 'marco@mail.it', phone = '3332220000' } = {}) {
  return ctx.auth.register({ name, email, phone, password: PASSWORD });
}

export function addEmployee(ctx, { name = 'Elena Gestore', email = 'elena@hut.it' } = {}) {
  const user = ctx.auth.register({ name, email, phone: '3331110000', password: PASSWORD });
  ctx.db.prepare("UPDATE users SET role = 'employee' WHERE uID = ?").run(user.uID);
  return { ...user, role: 'employee' };
}

// Creates a slot with its table layout directly in the database; tables = { table_no: seats }
export function addSlot(ctx, start, end, tables) {
  const tsID = Number(ctx.db.prepare('INSERT INTO timeslots(start_time, end_time) VALUES (?, ?)')
    .run(start, end).lastInsertRowid);
  const insert = ctx.db.prepare('INSERT INTO slot_tables(tsID, table_no, seats) VALUES (?, ?, ?)');
  for (const [tableNo, seats] of Object.entries(tables)) insert.run(tsID, Number(tableNo), seats);
  return tsID;
}

// Returns a supertest agent that keeps the session cookie after logging in
export async function loginAs(ctx, email) {
  const agent = request.agent(ctx.app);
  const res = await agent.post('/api/sessions').send({ email, password: PASSWORD });
  if (res.status !== 200) throw new Error(`Login failed for ${email}: ${res.status}`);
  return agent;
}

// Seats a booking holds, as { table_no: seats }
export function seatsOf(ctx, bID) {
  return Object.fromEntries(ctx.db.prepare(
    'SELECT table_no, seats FROM booking_tables WHERE bID = ? ORDER BY table_no').all(bID)
    .map(r => [r.table_no, r.seats]));
}
