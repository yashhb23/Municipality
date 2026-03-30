'use strict';

require('dotenv').config();

const { createApp, logger } = require('./app');

const PORT = process.env.PORT || 3001;

const app = createApp();

app.listen(PORT, () => {
  logger.info(`FixMo Backend API running on http://localhost:${PORT}`);
  logger.info('Routes: /health, /api/v1/{reports,municipalities,categories,auth,alerts,upload,admin,webhooks}');
});
