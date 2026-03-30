'use strict';

const { Router } = require('express');
const { supabaseAdmin } = require('../utils/supabaseAdmin');

const router = Router();

/**
 * GET /api/v1/categories
 * Public endpoint returning all categories with subcategories.
 * Falls back to a hardcoded list if the DB table doesn't exist yet.
 */
router.get('/', async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('categories')
    .select('*, subcategories(*)')
    .eq('is_active', true)
    .order('sort_order', { ascending: true });

  if (error) {
    req.log.warn({ error }, 'categories table not available, using fallback');
    const fallback = [
      'Potholes', 'Broken Street Lights', 'Garbage/Waste',
      'Drainage Issues', 'Road Damage', 'Graffiti',
      'Broken Infrastructure', 'Other',
    ].map((name, i) => ({ id: i + 1, name, icon: null, subcategories: [] }));

    return res.json({ ok: true, data: fallback });
  }

  res.json({ ok: true, data });
});

module.exports = router;
