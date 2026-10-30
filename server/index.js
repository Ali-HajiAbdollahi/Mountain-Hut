import { openDb } from './db.js';
import { createApp } from './app.js';
import { createBookingDao } from './dao/bookingDao.js';
import { createSlotDao } from './dao/slotDao.js';
import { createBookingService } from './services/bookingService.js';
import { createBookingRouter } from './routes/bookingRoutes.js';

const db=openDb();
db.exec('PRAGMA busy_timeout = 5000');
const service=createBookingService(createBookingDao(db),createSlotDao(db));
const bookingRouter=createBookingRouter(service);
const port=Number(process.env.PORT || 3001);
const server=createApp(db,{bookingRouter}).listen(port,()=>console.log(`API listening on port ${port}`));
function shutdown() { server.close(()=>{db.close();process.exit(0);}); }
process.on('SIGINT',shutdown);
process.on('SIGTERM',shutdown);