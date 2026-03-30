'use strict';

const { AppError } = require('../utils/errors');

/**
 * Express error-handling middleware.
 * Catches both AppError instances (known) and unexpected errors,
 * and returns a consistent JSON envelope.
 */
function errorHandler(err, req, res, _next) {
  const statusCode = err instanceof AppError ? err.statusCode : 500;
  const code = err instanceof AppError ? err.code : 'INTERNAL_ERROR';

  if (statusCode >= 500) {
    req.log.error({ err }, 'Unhandled server error');
  } else {
    req.log.warn({ err }, err.message);
  }

  const body = {
    ok: false,
    error: {
      code,
      message: err.message || 'An unexpected error occurred',
    },
  };

  if (err.details) {
    body.error.details = err.details;
  }

  res.status(statusCode).json(body);
}

module.exports = errorHandler;
