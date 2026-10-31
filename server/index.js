import { openDb } from './db.js';
import { createApp } from './app.js';
import { createAvailabilityDao } from './dao/availabilityDao.js';
import { createAvailabilityService } from './services/availabilityService.js';
import { createAvailabilityRouter } from './routes/availabilityRoutes.js';

const db = openDb();
db.exec('PRAGMA busy_timeout = 5000');

const availabilityDao = createAvailabilityDao(db);
const availabilityService = createAvailabilityService(availabilityDao);
const availabilityRouter = createAvailabilityRouter(availabilityService);

const app = createApp({ availabilityRouter });
const port = Number(process.env.PORT || 3001);

const server = app.listen(port, () => {
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