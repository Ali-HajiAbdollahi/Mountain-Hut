import { Router } from 'express';
import { requireRole } from '../middleware/auth.js';

export function createHikeRouter(service) {
  const router = Router();
  router.use(requireRole('hiker'));

  router.post('/', (req, res) => {
    const hike = service.create(req.body, req.user);
    res.status(201).json({ hike });
  });

  return router;
}
