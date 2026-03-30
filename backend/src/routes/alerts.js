'use strict';

const { Router } = require('express');
const { optionalAuth } = require('../middleware/auth');
const { supabaseAdmin } = require('../utils/supabaseAdmin');

const router = Router();

/**
 * GET /api/v1/alerts
 * List active alerts, optionally filtered by municipality.
 */
router.get('/', optionalAuth, async (req, res) => {
  const { municipality } = req.query;

  let query = supabaseAdmin
    .from('alerts')
    .select('*')
    .eq('is_read', false)
    .order('created_at', { ascending: false })
    .limit(50);

  if (municipality) {
    query = query.eq('municipality', municipality);
  }

  const { data, error } = await query;

  if (error) {
    req.log.warn({ error }, 'alerts table query failed, returning empty');
    return res.json({ ok: true, data: [] });
  }

  res.json({ ok: true, data });
});

module.exports = router;
