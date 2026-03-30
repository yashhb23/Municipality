'use strict';

const { Router } = require('express');

const router = Router();

router.get('/', (_req, res) => {
  res.json({
    ok: true,
    data: {
      status: 'healthy',
      version: process.env.npm_package_version || '1.0.0',
      timestamp: new Date().toISOString(),
    },
  });
});

module.exports = router;
