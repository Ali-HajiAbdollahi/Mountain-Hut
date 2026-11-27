import { Router } from 'express';
import { DateTime } from 'luxon';
import { requireRole } from '../middleware/auth.js';
import { dateOnly, HUT_ZONE } from '../domain/time.js';
import { onlyKeys } from '../domain/validation.js';
import { ValidationError } from '../errors.js';

export function createOccupancyRouter(dao) {
  const router = Router();
  router.get('/', requireRole('employee'), (req, res) => {
    onlyKeys(req.query, ['date', 'period']);
    const date = dateOnly(req.query.date);
    const period = req.query.period ?? 'day';
    if (!['day', 'week'].includes(period)) {
      throw new ValidationError('period must be day or week');
    }
    let from = DateTime.fromISO(date, { zone: HUT_ZONE }).startOf('day');
    if (period === 'week') from = from.startOf('week');
    const to = from.plus({ days: period === 'week' ? 7 : 1 });
    const format = 'yyyy-MM-dd HH:mm';
    res.json({ period, from: from.toFormat(format), to: to.toFormat(format),
      slots: dao.occupancyInRange(from.toFormat(format), to.toFormat(format)) });
  });
  return router;
}