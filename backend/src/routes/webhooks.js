'use strict';

const { Router } = require('express');
const crypto = require('crypto');
const { AuthenticationError } = require('../utils/errors');

const router = Router();

const WEBHOOK_SECRET = process.env.SUPABASE_WEBHOOK_SECRET;

/**
 * Verify the HMAC signature on incoming Supabase webhooks.
 * The signature is expected in the `x-webhook-signature` header.
 */
function verifyWebhookSignature(req, _res, next) {
  if (!WEBHOOK_SECRET) {
    req.log.warn('SUPABASE_WEBHOOK_SECRET not set — skipping signature check');
    return next();
  }

  const signature = req.headers['x-webhook-signature'];
  if (!signature) {
    throw new AuthenticationError('Missing webhook signature');
  }

  const rawBody = JSON.stringify(req.body);
  const expected = crypto
    .createHmac('sha256', WEBHOOK_SECRET)
    .update(rawBody)
    .digest('hex');

  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
    throw new AuthenticationError('Invalid webhook signature');
  }

  next();
}

/**
 * POST /api/v1/webhooks/report-created
 * Called by Supabase when a new report row is inserted.
 */
router.post('/report-created', verifyWebhookSignature, async (req, res) => {
  const { record } = req.body;
  if (record) {
    req.log.info({ reportId: record.id }, 'Webhook: report-created');
  }
  res.json({ ok: true });
});

module.exports = router;
