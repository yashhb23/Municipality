'use strict';

const { verifySupabaseJwt } = require('../utils/supabaseJwt');
const { AuthenticationError, ForbiddenError } = require('../utils/errors');

/**
 * Middleware that verifies the Supabase JWT from the Authorization header.
 * On success, attaches `req.user` with the decoded token payload.
 *
 * Usage:
 *   router.post('/reports', requireAuth, handler);
 */
function requireAuth(req, _res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    throw new AuthenticationError('Missing or malformed Authorization header');
  }

  const token = header.slice(7);
  try {
    req.user = verifySupabaseJwt(token);
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      throw new AuthenticationError('Token has expired');
    }
    throw new AuthenticationError('Invalid token');
  }
  next();
}

/**
 * Factory that returns middleware restricting access to specific roles.
 *
 * @param  {...string} allowedRoles  e.g. 'service_role', 'authenticated'
 */
function requireRole(...allowedRoles) {
  return (req, _res, next) => {
    if (!req.user) {
      throw new AuthenticationError();
    }
    if (!allowedRoles.includes(req.user.role)) {
      throw new ForbiddenError(
        `Role "${req.user.role}" is not authorized. Required: ${allowedRoles.join(', ')}`,
      );
    }
    next();
  };
}

/**
 * Optional auth — sets req.user if a valid token is present but does not
 * reject the request if it is missing or invalid.
 */
function optionalAuth(req, _res, next) {
  const header = req.headers.authorization;
  if (header && header.startsWith('Bearer ')) {
    try {
      req.user = verifySupabaseJwt(header.slice(7));
    } catch {
      req.user = null;
    }
  }
  next();
}

module.exports = { requireAuth, requireRole, optionalAuth };
