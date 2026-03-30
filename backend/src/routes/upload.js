'use strict';

const { Router } = require('express');
const multer = require('multer');
const crypto = require('crypto');
const { requireAuth } = require('../middleware/auth');
const { uploadLimiter } = require('../middleware/rateLimiter');
const { validateImageBuffer, processImage, MAX_IMAGE_SIZE } = require('../services/imageService');
const { supabaseAdmin } = require('../utils/supabaseAdmin');
const { ValidationError } = require('../utils/errors');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_IMAGE_SIZE },
});

const router = Router();

/**
 * POST /api/v1/upload
 * Upload a report image. Validates magic bytes, strips EXIF,
 * re-encodes as JPEG, and generates a 200x200 thumbnail.
 */
router.post(
  '/',
  requireAuth,
  uploadLimiter,
  upload.single('image'),
  async (req, res) => {
    if (!req.file) {
      throw new ValidationError('No image file provided');
    }

    const validation = validateImageBuffer(req.file.buffer);
    if (!validation.valid) {
      throw new ValidationError(validation.error);
    }

    const { full, thumbnail } = await processImage(req.file.buffer);

    const id = crypto.randomUUID();
    const fullPath = `reports/${id}.jpg`;
    const thumbPath = `reports/${id}_thumb.jpg`;

    // Upload full image and thumbnail in parallel
    const [fullResult, thumbResult] = await Promise.all([
      supabaseAdmin.storage
        .from('report-images')
        .upload(fullPath, full, { contentType: 'image/jpeg', upsert: false }),
      supabaseAdmin.storage
        .from('report-images')
        .upload(thumbPath, thumbnail, { contentType: 'image/jpeg', upsert: false }),
    ]);

    if (fullResult.error) {
      req.log.error({ error: fullResult.error }, 'Full image upload failed');
      throw new Error('Failed to upload image');
    }

    const { data: fullUrl } = supabaseAdmin.storage.from('report-images').getPublicUrl(fullPath);
    const { data: thumbUrl } = supabaseAdmin.storage.from('report-images').getPublicUrl(thumbPath);

    req.log.info({
      originalSize: req.file.buffer.length,
      processedSize: full.length,
      thumbnailSize: thumbnail.length,
    }, 'Image processed and uploaded');

    res.status(201).json({
      ok: true,
      data: {
        url: fullUrl.publicUrl,
        thumbnail_url: thumbResult.error ? null : thumbUrl.publicUrl,
        path: fullPath,
      },
    });
  },
);

module.exports = router;
