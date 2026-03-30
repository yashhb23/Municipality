'use strict';

const { Router } = require('express');
const { requireAuth } = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimiter');
const validate = require('../middleware/validate');
const { registerDeviceSchema, updatePushTokenSchema } = require('../schemas/authSchemas');
const { supabaseAdmin } = require('../utils/supabaseAdmin');

const router = Router();

/**
 * POST /api/v1/auth/device
 * Register a device (or update existing) and associate it with the current user.
 */
router.post(
  '/device',
  authLimiter,
  requireAuth,
  validate(registerDeviceSchema),
  async (req, res) => {
    const { device_id, platform, push_token } = req.body;
    const userId = req.user.sub;

    const { data, error } = await supabaseAdmin
      .from('device_registrations')
      .upsert(
        { device_id, platform, user_id: userId, push_token: push_token || null },
        { onConflict: 'device_id' },
      )
      .select()
      .single();

    if (error) {
      req.log.error({ error }, 'Device registration failed');
      throw new Error('Failed to register device');
    }

    res.status(201).json({ ok: true, data });
  },
);

/**
 * PUT /api/v1/auth/push-token
 * Update the push notification token for the authenticated user's device.
 */
router.put(
  '/push-token',
  requireAuth,
  validate(updatePushTokenSchema),
  async (req, res) => {
    const { push_token } = req.body;
    const userId = req.user.sub;

    const { error } = await supabaseAdmin
      .from('device_registrations')
      .update({ push_token })
      .eq('user_id', userId);

    if (error) {
      req.log.error({ error }, 'Push token update failed');
      throw new Error('Failed to update push token');
    }

    res.json({ ok: true, data: { updated: true } });
  },
);

module.exports = router;
