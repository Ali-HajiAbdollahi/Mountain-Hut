import { Router } from 'express';
import { requireRole } from '../middleware/auth.js';
import { pathId, onlyKeys } from '../domain/validation.js';
import { bookingConfirmation } from '../mail/bookingConfirmation.js';
import { bookingUpdated } from '../mail/bookingUpdated.js';

export function createBookingRouter(service,mail,changeService) {
  const router=Router();
  router.use(requireRole('hiker'));
  router.post('/',async (req,res)=>{
    const booking=service.create(req.body,req.user); // transaction already committed
    const notification=await mail.send(req.user.email,bookingConfirmation(booking));
    res.location(`/api/bookings/${booking.bID}`).status(201).json({booking,notification});
  });
  router.get('/',(req,res)=>res.json(service.list(req.user)));
  router.get('/:id',(req,res)=>res.json(service.owned(pathId(req.params.id),req.user)));
  
  router.delete('/:id', (req, res) => {
    service.cancel(pathId(req.params.id), req.user);
    res.status(204).end();
  });

  router.patch('/:id', async (req, res) => {
    const booking = changeService.update(
      pathId(req.params.id),
      req.body,
      req.user,
    );
    // The change is already committed: a mail failure must not undo it.
    let notification;
    try {
      notification = await mail.send(req.user.email, bookingUpdated(booking));
    } catch (error) {
      console.error('Booking change email failed', { code: error.code });
      notification = { status: 'failed' };
    }

    res.json({ booking, notification });
  });

  router.post('/:id/confirmation',async (req,res)=>{
    onlyKeys(req.body ?? {},[]);
    const booking=service.owned(pathId(req.params.id),req.user);
    const notification=await mail.send(req.user.email,bookingConfirmation(booking));
    res.json({bookingReference:booking.reference,notification});
  });
  return router;
}
