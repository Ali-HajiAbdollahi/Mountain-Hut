import { Router } from 'express';
import { requireRole } from '../middleware/auth.js';
import { pathId } from '../domain/validation.js';

export function createBookingRouter(service) {
  const router=Router();
  router.use(requireRole('hiker'));
  router.post('/',(req,res)=>{
    const booking=service.create(req.body,req.user);
    res.location(`/api/bookings/${booking.bID}`).status(201).json({booking});
  });
  router.get('/',(req,res)=>res.json(service.list(req.user)));
  router.get('/:id',(req,res)=>res.json(service.owned(pathId(req.params.id),req.user)));
  return router;
}