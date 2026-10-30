import { openDb } from './db.js';
import { createApp } from './app.js';

const db=openDb();
db.exec('PRAGMA busy_timeout = 5000');
const port=Number(process.env.PORT || 3001);
const server=createApp(db).listen(port,()=>console.log(`API listening on port ${port}`));
function shutdown() { server.close(()=>{db.close();process.exit(0);}); }
process.on('SIGINT',shutdown);
process.on('SIGTERM',shutdown);