'use strict';

const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.SUPABASE_JWT_SECRET;

/**
 * Verify a Supabase-issued JWT and return the decoded payload.
 *
 * @param {string} token  Bearer token (without the "Bearer " prefix).
 * @returns {{ sub: string, role: string, iat: number, exp: number }}
 * @throws {jwt.JsonWebTokenError | jwt.TokenExpiredError}
 */
function verifySupabaseJwt(token) {
  if (!JWT_SECRET) {
    throw new Error(
      'SUPABASE_JWT_SECRET environment variable is not set. '
      + 'Find it in Supabase → Settings → API → JWT Secret.',
    );
  }
  return jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
}

module.exports = { verifySupabaseJwt };
