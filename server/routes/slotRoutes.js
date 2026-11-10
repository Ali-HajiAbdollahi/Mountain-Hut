import { Router } from 'express';
import { pathId } from '../domain/validation.js';
import { requireRole } from '../middleware/auth.js';

export function createSlotRouter(service) {
  const router = Router();
  router.post('/repeat-week', requireRole('employee'), (req, res) => {
    res.status(201).json(service.repeatWeek(req.body));
  });
  router.get('/',(req,res)=>res.json(service.list(req.query.date)));
  router.get('/:id',(req,res)=>res.json(service.details(pathId(req.params.id))));
  router.post('/',requireRole('employee'),(req,res)=>{
    const slot=service.create(req.body);
    res.location(`/api/timeslots/${slot.tsID}`).status(201).json(slot);
  });
  router.put('/:id/tables',requireRole('employee'),(req,res)=>
    res.json(service.defineTables(pathId(req.params.id),req.body)));
  return router;
}