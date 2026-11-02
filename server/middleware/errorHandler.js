import { ValidationError, ConflictError, AuthenticationError,
  ForbiddenError, NotFoundError } from '../errors.js';

export function errorHandler(err,req,res,next) {
  if (res.headersSent) return next(err);
  let status = 500, code = 'INTERNAL_ERROR', message = 'Internal server error';
  if (err instanceof ValidationError || err.type === 'entity.parse.failed')
    [status,code,message] = [400,'VALIDATION_ERROR',err instanceof ValidationError ? err.message : 'Invalid JSON'];
  else if (err instanceof AuthenticationError)
    [status,code,message] = [401,'UNAUTHENTICATED',err.message];
  else if (err instanceof ForbiddenError)
    [status,code,message] = [403,'FORBIDDEN',err.message];
  else if (err instanceof NotFoundError)
    [status,code,message] = [404,'NOT_FOUND',err.message];
  else if (err instanceof ConflictError || (err.errcode & 255) === 19)
    [status,code,message] = [409,'CONFLICT',err instanceof ConflictError ? err.message : 'Data conflicts with existing records'];
  else if ((err.errcode & 255) === 5) {
    [status,code,message] = [503,'DATABASE_BUSY','Please retry shortly'];
    res.set('Retry-After','1');
  } else if (err.type === 'entity.too.large')
    [status,code,message] = [413,'PAYLOAD_TOO_LARGE','Request body too large'];
  if (status === 500) console.error('Request failed', {code:err.code,name:err.name});
  res.status(status).json({error:{code,message}});
}