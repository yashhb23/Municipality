'use strict';

const sharp = require('sharp');

const ALLOWED_SIGNATURES = [
  { ext: 'jpg', bytes: [0xFF, 0xD8, 0xFF] },
  { ext: 'png', bytes: [0x89, 0x50, 0x4E, 0x47] },
  { ext: 'webp', bytes: [0x52, 0x49, 0x46, 0x46] },
];

const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5 MB
const FULL_IMAGE_WIDTH = 1920;
const THUMBNAIL_WIDTH = 200;
const THUMBNAIL_HEIGHT = 200;

/**
 * Validate an image buffer by checking magic bytes and file size.
 *
 * @param {Buffer} buffer
 * @returns {{ valid: boolean, ext?: string, error?: string }}
 */
function validateImageBuffer(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0) {
    return { valid: false, error: 'Empty or invalid buffer' };
  }
  if (buffer.length > MAX_IMAGE_SIZE) {
    return { valid: false, error: `File exceeds ${MAX_IMAGE_SIZE / 1024 / 1024} MB limit` };
  }

  for (const sig of ALLOWED_SIGNATURES) {
    if (sig.bytes.every((byte, i) => buffer[i] === byte)) {
      return { valid: true, ext: sig.ext };
    }
  }

  return { valid: false, error: 'Unsupported image format. Allowed: JPEG, PNG, WebP' };
}

/**
 * Process an uploaded image:
 * 1. Strip EXIF/metadata (privacy)
 * 2. Re-encode as JPEG at 85% quality
 * 3. Resize if wider than FULL_IMAGE_WIDTH
 * 4. Generate a 200x200 thumbnail
 *
 * @param {Buffer} buffer  Raw upload bytes.
 * @returns {Promise<{ full: Buffer, thumbnail: Buffer }>}
 */
async function processImage(buffer) {
  const pipeline = sharp(buffer).rotate(); // auto-orient from EXIF before stripping

  const full = await pipeline
    .clone()
    .resize({ width: FULL_IMAGE_WIDTH, withoutEnlargement: true })
    .jpeg({ quality: 85, mozjpeg: true })
    .toBuffer();

  const thumbnail = await pipeline
    .clone()
    .resize({ width: THUMBNAIL_WIDTH, height: THUMBNAIL_HEIGHT, fit: 'cover' })
    .jpeg({ quality: 70 })
    .toBuffer();

  return { full, thumbnail };
}

module.exports = {
  validateImageBuffer,
  processImage,
  MAX_IMAGE_SIZE,
  ALLOWED_SIGNATURES,
};
