'use strict';

const { z } = require('zod');

/** Schema for POST /api/v1/auth/device */
const registerDeviceSchema = z.object({
  device_id: z
    .string()
    .trim()
    .min(1, 'device_id is required')
    .max(255),

  platform: z.enum(['android', 'ios', 'web']),

  push_token: z
    .string()
    .trim()
    .max(500)
    .optional(),
});

/** Schema for PUT /api/v1/auth/push-token */
const updatePushTokenSchema = z.object({
  push_token: z
    .string()
    .trim()
    .min(1)
    .max(500),
});

module.exports = {
  registerDeviceSchema,
  updatePushTokenSchema,
};
