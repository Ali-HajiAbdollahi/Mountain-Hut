import express from 'express';
import cors from 'cors';
import session from 'express-session';
import { createUserDao } from './dao/userDao.js';
import { createAuthService } from './services/authService.js';
import { createSlotDao } from './dao/slotDao.js';
import { createSlotService } from './services/slotService.js';
import { loadUser } from './middleware/auth.js';
import { errorHandler } from './middleware/errorHandler.js';
import { createAuthRouter } from './routes/authRoutes.js';
import { createSlotRouter } from './routes/slotRoutes.js';

export function createApp(db,{bookingRouter} = {}) {
  const app = express();
  const origin = process.env.CLIENT_ORIGIN || 'http://localhost:5173';
  if (!process.env.SESSION_SECRET || process.env.SESSION_SECRET.length < 32)
    throw new Error('SESSION_SECRET must contain at least 32 characters');
  app.disable('x-powered-by');
  app.use(cors({origin,credentials:true}));
  // Browser writes must originate from the configured frontend.
  app.use((req,res,next)=>{
    if (!['GET','HEAD','OPTIONS'].includes(req.method) && req.get('Origin') && req.get('Origin') !== origin)
      return res.status(403).json({error:{code:'FORBIDDEN',message:'Origin not allowed'}});
    next();
  });
  app.use(express.json({limit:'64kb'}));
  app.use(session({name:'mh.sid',secret:process.env.SESSION_SECRET,
    resave:false,saveUninitialized:false,
    cookie:{httpOnly:true,sameSite:'lax',secure:false,maxAge:8*60*60*1000}}));
  const userDao=createUserDao(db);
  app.use(loadUser(userDao));
  app.get('/api/health',(req,res)=>res.json({status:'ok'}));
  app.use('/api',createAuthRouter(createAuthService(userDao)));
  app.use('/api/timeslots',createSlotRouter(createSlotService(createSlotDao(db))));
  if (bookingRouter) app.use('/api/bookings',bookingRouter);
  app.use((req,res)=>res.status(404).json({error:{code:'NOT_FOUND',message:'Endpoint not found'}}));
  app.use(errorHandler);
  return app;
}