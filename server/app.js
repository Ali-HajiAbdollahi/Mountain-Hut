import express from 'express';
import cors from 'cors';
import { ValidationError } from './errors.js';

export function createApp({ availabilityRouter } = {}) {
  const app = express();
  const origin = process.env.CLIENT_ORIGIN || 'http://localhost:5173';

  app.disable('x-powered-by');
  app.use(cors({ origin, credentials: true }));
  app.use(express.json({ limit: '64kb' }));

  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok' });
  });

  // MH-04: availability check is public; no login required.
  if (availabilityRouter) {
    app.use('/api/availability', availabilityRouter);
  }

  app.use((req, res) => {
    res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: 'Endpoint not found',
      },
    });
  });

  // Express sends errors thrown by a route or service here.
  app.use((err, req, res, next) => {
    if (err instanceof ValidationError) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: err.message,
        },
      });
    }

    console.error(err);
    return res.status(500).json({
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      },
    });
  });

  return app;
}