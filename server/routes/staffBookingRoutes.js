import { Router } from 'express';
import { requireRole } from '../middleware/auth.js';

export function createStaffBookingRouter(service) {
  const router = Router();

  // only allows employee
  router.use(requireRole('employee'));

  router.get('/hikers', (req, res) => {
    const hikers = service.searchHikers(req.query.query, req.user);
    res.json({ hikers });
  });

  router.post('/bookings', (req, res) => {
    const booking = service.create(req.body, req.user);

    res
      .location(`/api/bookings/${booking.bID}`)
      .status(201)
      .json({ booking });
  });

  return router;
}