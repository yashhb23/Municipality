'use strict';

const rateLimit = require('express-rate-limit');

/**
 * Default limiter: 100 requests per 15-minute window per IP.
 */
const defaultLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    ok: false,
    error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many requests, please try again later.' },
  },
});

/** Report creation: tighter limit — 10 per 15 min per IP. */
const createReportLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    ok: false,
    error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Report creation rate limit reached.' },
  },
});

/** Image upload: 20 per 15 min per IP. */
const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    ok: false,
    error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Upload rate limit reached.' },
  },
});

/** Auth endpoints: 30 per 15 min per IP. */
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    ok: false,
    error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Auth rate limit reached.' },
  },
});

module.exports = {
  defaultLimiter,
  createReportLimiter,
  uploadLimiter,
  authLimiter,
};
