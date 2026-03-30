'use strict';

const { Router } = require('express');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const { createReportLimiter } = require('../middleware/rateLimiter');
const validate = require('../middleware/validate');
const {
  createReportSchema,
  updateReportStatusSchema,
  listReportsQuerySchema,
  reportIdParamSchema,
} = require('../schemas/reportSchemas');
const reportService = require('../services/reportService');

const router = Router();

/**
 * POST /api/v1/reports
 * Create a new civic report. Requires authentication.
 */
router.post(
  '/',
  requireAuth,
  createReportLimiter,
  validate(createReportSchema),
  async (req, res) => {
    const report = await reportService.createReport(
      req.body,
      req.user?.sub || null,
      req.log,
    );
    res.status(201).json({ ok: true, data: report });
  },
);

/**
 * GET /api/v1/reports
 * List reports with optional filters. Public endpoint.
 */
router.get(
  '/',
  optionalAuth,
  validate(listReportsQuerySchema, 'query'),
  async (req, res) => {
    const { reports, total } = await reportService.listReports(req.query);
    res.json({
      ok: true,
      data: reports,
      meta: { total, limit: req.query.limit, offset: req.query.offset },
    });
  },
);

/**
 * GET /api/v1/reports/:id
 * Get a single report by ID. Public endpoint.
 */
router.get(
  '/:id',
  validate(reportIdParamSchema, 'params'),
  async (req, res) => {
    const report = await reportService.getReportById(req.params.id);
    res.json({ ok: true, data: report });
  },
);

/**
 * PATCH /api/v1/reports/:id/status
 * Update report status. Staff-only endpoint.
 */
router.patch(
  '/:id/status',
  requireAuth,
  validate(reportIdParamSchema, 'params'),
  validate(updateReportStatusSchema),
  async (req, res) => {
    const updated = await reportService.updateReportStatus(
      req.params.id,
      req.body.status,
      req.body.note || null,
      req.user.sub,
      req.log,
    );
    res.json({ ok: true, data: updated });
  },
);

module.exports = router;
