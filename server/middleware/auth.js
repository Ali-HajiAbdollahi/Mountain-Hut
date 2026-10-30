import { AuthenticationError, ForbiddenError } from '../errors.js';

export function loadUser(userDao) {
  return (req,res,next)=>{
    const row = req.session.uID ? userDao.findById(req.session.uID) : undefined;
    if (row) {
      const {uID,name,email,phone,role} = row;
      req.user = {uID,name,email,phone,role};
    }
    next();
  };
}
export function requireLogin(req,res,next) {
  if (!req.user) return next(new AuthenticationError('Login required'));
  next();
}
export function requireRole(role) {
  return (req,res,next)=>{
    if (!req.user) return next(new AuthenticationError('Login required'));
    if (req.user.role !== role) return next(new ForbiddenError('Operation not allowed'));
    next();
  };
}