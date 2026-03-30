'use strict';

const { ValidationError } = require('../utils/errors');

/**
 * Factory that returns Express middleware to validate request data
 * against a Zod schema.
 *
 * @param {import('zod').ZodSchema} schema  The Zod schema to validate against.
 * @param {'body' | 'query' | 'params'} [source='body']  Which part of the request to validate.
 * @returns {import('express').RequestHandler}
 *
 * @example
 *   router.post('/reports', validate(createReportSchema), handler);
 */
function validate(schema, source = 'body') {
  return (req, _res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const details = result.error.issues.map((issue) => ({
        field: issue.path.join('.'),
        message: issue.message,
      }));
      throw new ValidationError('Request validation failed', details);
    }
    req[source] = result.data;
    next();
  };
}

module.exports = validate;
