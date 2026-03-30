'use strict';

const { Router } = require('express');
const { supabaseAdmin } = require('../utils/supabaseAdmin');

const router = Router();

/**
 * GET /api/v1/municipalities
 * Public endpoint returning all municipalities.
 * Falls back to a hardcoded list if the DB table doesn't exist yet.
 */
router.get('/', async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('municipalities')
    .select('*')
    .order('name', { ascending: true });

  if (error) {
    req.log.warn({ error }, 'municipalities table not available, using fallback');
    const fallback = [
      'Port Louis', 'Curepipe', 'Quatre Bornes', 'Beau Bassin-Rose Hill',
      'Vacoas-Phoenix', 'Mahébourg', 'Flacq', 'Goodlands', 'Triolet', 'Black River',
    ].map((name, i) => ({ id: i + 1, name }));

    return res.json({ ok: true, data: fallback });
  }

  res.json({ ok: true, data });
});

module.exports = router;
