'use strict';

const { Router } = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { supabaseAdmin } = require('../utils/supabaseAdmin');

const router = Router();

/**
 * GET /api/v1/admin/stats
 * Dashboard statistics. Service-role or authenticated staff only.
 */
router.get(
  '/stats',
  requireAuth,
  requireRole('service_role', 'authenticated'),
  async (req, res) => {
    const [
      { count: totalReports },
      { count: pendingReports },
      { count: resolvedReports },
    ] = await Promise.all([
      supabaseAdmin.from('reports').select('*', { count: 'exact', head: true }),
      supabaseAdmin.from('reports').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
      supabaseAdmin.from('reports').select('*', { count: 'exact', head: true }).eq('status', 'resolved'),
    ]);

    res.json({
      ok: true,
      data: {
        total_reports: totalReports || 0,
        pending_reports: pendingReports || 0,
        resolved_reports: resolvedReports || 0,
      },
    });
  },
);

module.exports = router;
