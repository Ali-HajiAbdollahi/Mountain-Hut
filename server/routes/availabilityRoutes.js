import { Router } from 'express';

export function createAvailabilityRouter(service) {
  const router = Router();

  router.get('/', (req, res) => {
    const result = service.check({
      date: req.query.date,
      time: req.query.time,
      partySize: req.query.partySize,
    });

    res.json(result);
  });

  return router;
}