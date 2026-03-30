'use strict';

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const pinoHttp = require('pino-http');
const pino = require('pino');

const errorHandler = require('./middleware/errorHandler');
const { defaultLimiter } = require('./middleware/rateLimiter');

// Route modules
const healthRouter = require('./routes/health');
const reportsRouter = require('./routes/reports');
const municipalitiesRouter = require('./routes/municipalities');
const categoriesRouter = require('./routes/categories');
const authRouter = require('./routes/auth');
const alertsRouter = require('./routes/alerts');
const uploadRouter = require('./routes/upload');
const adminRouter = require('./routes/admin');
const webhooksRouter = require('./routes/webhooks');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport:
    process.env.NODE_ENV !== 'production'
      ? { target: 'pino-pretty', options: { colorize: true } }
      : undefined,
});

function createApp() {
  const app = express();

  // ── Global Middleware ──────────────────────────────────────────────
  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));
  app.use(pinoHttp({ logger }));
  app.use(defaultLimiter);

  // ── Routes ─────────────────────────────────────────────────────────
  app.use('/health', healthRouter);
  app.use('/api/v1/reports', reportsRouter);
  app.use('/api/v1/municipalities', municipalitiesRouter);
  app.use('/api/v1/categories', categoriesRouter);
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/alerts', alertsRouter);
  app.use('/api/v1/upload', uploadRouter);
  app.use('/api/v1/admin', adminRouter);
  app.use('/api/v1/webhooks', webhooksRouter);

  // ── Error Handler (must be last) ──────────────────────────────────
  app.use(errorHandler);

  return app;
}

module.exports = { createApp, logger };
