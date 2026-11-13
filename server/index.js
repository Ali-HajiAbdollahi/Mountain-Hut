import { openDb } from './db.js';
import { createApp } from './app.js';
import { createBookingDao } from './dao/bookingDao.js';
import { createSlotDao } from './dao/slotDao.js';
import { createBookingService } from './services/bookingService.js';
import { createBookingRouter } from './routes/bookingRoutes.js';
import { createMailService } from './services/mailService.js';
import { createBookingChangeService } from './services/bookingChangeService.js';
import { createUserDao } from './dao/userDao.js';
import { createAuthService } from './services/authService.js';
import { createStaffBookingService } from './services/staffBookingService.js';
import { createStaffBookingRouter } from './routes/staffBookingRoutes.js';
import { createHikeDao } from './dao/hikeDao.js';
import { createHikeService } from './services/hikeService.js';
import { createHikeRouter } from './routes/hikeRoutes.js';

const db = openDb();
db.exec('PRAGMA busy_timeout = 5000');

const bookingDao = createBookingDao(db);
const slotDao = createSlotDao(db);

const service = createBookingService(bookingDao, slotDao);
const changeService = createBookingChangeService(bookingDao, slotDao);
const bookingRouter = createBookingRouter(
  service,
  createMailService(),
  changeService,
);
const staffUsers = createUserDao(db);
const staffAuth = createAuthService(staffUsers);
const staffService = createStaffBookingService(
  staffUsers,
  bookingDao,
  slotDao,
  staffAuth,
);
const staffBookingRouter = createStaffBookingRouter(staffService);
const hikeDao = createHikeDao(db);
const hikeService = createHikeService(hikeDao);
const hikeRouter = createHikeRouter(hikeService);
const port = Number(process.env.PORT || 3001);
const server = createApp(db, { bookingRouter, staffBookingRouter, hikeRouter }).listen(port, () => {
  console.log(`API listening on port ${port}`);
});

function shutdown() {
  server.close(() => {
    db.close();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
