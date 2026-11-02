import { Router } from 'express';
import { onlyKeys } from '../domain/validation.js';
import { ValidationError } from '../errors.js';
import { requireLogin } from '../middleware/auth.js';

export function createAuthRouter(auth) {
  const router = Router();
  function startSession(req,res,next,user,status) {
    req.session.regenerate(err=>{
      if (err) return next(err);
      req.session.uID = user.uID;
      req.session.save(err=>err ? next(err) : res.status(status).json(user));
    });
  }
  router.post('/sessions',(req,res,next)=>{
    onlyKeys(req.body,['email','password']);
    if (typeof req.body.email !== 'string' || typeof req.body.password !== 'string')
      throw new ValidationError('email and password must be strings');
    startSession(req,res,next,auth.login(req.body),200);
  });
  router.post('/users',(req,res,next)=>{
    onlyKeys(req.body,['name','email','phone','password']);
    for (const key of ['name','email','phone','password'])
      if (typeof req.body[key] !== 'string' || !req.body[key].trim())
        throw new ValidationError(`${key} is required and must be a string`);
    startSession(req,res,next,auth.register(req.body),201);
  });
  router.get('/sessions/current',requireLogin,(req,res)=>res.json(req.user));
  router.delete('/sessions/current',(req,res,next)=>{
    req.session.destroy(err=>{
      if (err) return next(err);
      res.clearCookie('mh.sid',{path:'/'}).status(204).end();
    });
  });
  return router;
}