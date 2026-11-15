import { Router } from 'express';
import { requireRole } from '../middleware/auth.js';

export function createHikeRouter(service) {
  const router = Router();

  router.post('/', requireRole('hiker'), (req, res) => {
    const hike = service.create(req.body, req.user);
    res.status(201).json({ hike });
  });

  router.get('/active', requireRole('employee'), (req, res) => {
    res.json(service.listActive(req.user));
  });

  return router;
}
