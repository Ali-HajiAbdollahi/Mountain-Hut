import { Router } from 'express';
import { onlyKeys } from '../domain/validation.js';
import { ValidationError } from '../errors.js';
import { requireLogin } from '../middleware/auth.js';
import { passwordReset } from '../mail/passwordReset.js';

export function createAuthRouter(auth, { mail, resetUrl = 'http://localhost:5173/reset-password' } = {}) {
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
  router.put('/users/current/password',requireLogin,(req,res)=>{
    onlyKeys(req.body,['current_password','new_password']);
    res.json(auth.changePassword(req.user.uID,req.body));
  });
  // Same answer whether the email exists or not, and the email is sent after answering,
  // so neither the body nor the response time reveals which addresses are registered.
  router.post('/password-resets',(req,res)=>{
    onlyKeys(req.body,['email']);
    if (typeof req.body.email !== 'string' || !req.body.email.trim())
      throw new ValidationError('email is required and must be a string');
    const issued=auth.requestPasswordReset(req.body.email);
    if (issued && mail) {
      mail.send(issued.user.email,passwordReset({name:issued.user.name,token:issued.token,resetUrl}))
        .catch(()=>{});
    }
    res.status(202).json({status:'accepted'});
  });
  router.post('/password-resets/confirm',(req,res)=>{
    onlyKeys(req.body,['token','new_password']);
    auth.resetPassword(req.body.token,req.body.new_password);
    res.status(204).end();
  });
  router.delete('/sessions/current',(req,res,next)=>{
    req.session.destroy(err=>{
      if (err) return next(err);
      res.clearCookie('mh.sid',{path:'/'}).status(204).end();
    });
  });
  return router;
}