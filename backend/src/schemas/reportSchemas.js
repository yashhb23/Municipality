'use strict';

const { z } = require('zod');

/** Schema for POST /api/v1/reports */
const createReportSchema = z.object({
  title: z
    .string()
    .trim()
    .min(3, 'Title must be at least 3 characters')
    .max(200, 'Title must be at most 200 characters'),

  description: z
    .string()
    .trim()
    .max(500, 'Description must be at most 500 characters')
    .default(''),

  category: z
    .string()
    .trim()
    .min(1, 'Category is required'),

  subcategory: z
    .string()
    .trim()
    .optional(),

  municipality: z
    .string()
    .trim()
    .min(1, 'Municipality is required'),

  latitude: z
    .number()
    .min(-90)
    .max(90),

  longitude: z
    .number()
    .min(-180)
    .max(180),

  address: z
    .string()
    .trim()
    .max(500)
    .optional(),

  image_url: z
    .string()
    .url()
    .optional(),

  idempotency_key: z
    .string()
    .uuid()
    .optional(),
});

/** Schema for PATCH /api/v1/reports/:id/status */
const updateReportStatusSchema = z.object({
  status: z.enum([
    'pending',
    'acknowledged',
    'in_progress',
    'resolved',
    'closed',
    'rejected',
  ]),
  note: z
    .string()
    .trim()
    .max(1000)
    .optional(),
});

/** Schema for GET /api/v1/reports query params */
const listReportsQuerySchema = z.object({
  municipality: z.string().optional(),
  category: z.string().optional(),
  status: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

/** Schema for report ID param */
const reportIdParamSchema = z.object({
  id: z.string().uuid('Invalid report ID'),
});

module.exports = {
  createReportSchema,
  updateReportStatusSchema,
  listReportsQuerySchema,
  reportIdParamSchema,
};
