import { AuthenticationError, ForbiddenError, PasswordChangeRequiredError } from '../errors.js';

export function loadUser(userDao) {
  return (req,res,next)=>{
    const row = req.session.uID ? userDao.findById(req.session.uID) : undefined;
    if (row) {
      const {uID,name,email,phone,role} = row;
      req.user = {uID,name,email,phone,role,must_change_password:row.must_change_password === 1};
    }
    next();
  };
}
// An account with a temporary password may only change it, read its session or log out.
const ALLOWED_WHILE_PASSWORD_CHANGE_PENDING = new Set([
  'GET /api/health',
  'GET /api/sessions/current',
  'DELETE /api/sessions/current',
  'POST /api/sessions',
  'PUT /api/users/current/password',
  'POST /api/password-resets',
  'POST /api/password-resets/confirm',
]);
export function requirePasswordChanged(req,res,next) {
  if (req.user?.must_change_password && !ALLOWED_WHILE_PASSWORD_CHANGE_PENDING.has(`${req.method} ${req.path}`))
    return next(new PasswordChangeRequiredError('You must change your password before continuing'));
  next();
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