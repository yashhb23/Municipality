'use strict';

const crypto = require('crypto');
const { supabaseAdmin } = require('../utils/supabaseAdmin');
const { NotFoundError, ValidationError } = require('../utils/errors');
const { notifyMunicipality } = require('./notificationService');
const { writeAuditLog } = require('./auditService');
const geohash = require('../utils/geohash');

/** Valid status transitions (state machine). */
const VALID_TRANSITIONS = {
  submitted: ['accepted', 'rejected', 'duplicate'],
  accepted: ['triaged', 'assigned', 'in_progress', 'rejected'],
  triaged: ['assigned', 'in_progress', 'rejected'],
  assigned: ['in_progress', 'info_needed', 'rejected'],
  info_needed: ['in_progress', 'rejected'],
  in_progress: ['resolved', 'info_needed', 'rejected'],
  resolved: ['closed', 'reopened'],
  reopened: ['in_progress', 'rejected'],
  rejected: [],
  closed: [],
  duplicate: [],
  archived: [],
  // Legacy status support (for existing v1.x data)
  pending: ['accepted', 'acknowledged', 'rejected'],
  acknowledged: ['in_progress', 'rejected'],
};

/**
 * Compute a SHA-256 content hash for duplicate detection.
 * Based on category + municipality + truncated coordinates.
 */
function computeContentHash(data) {
  const normalized = [
    data.category,
    data.municipality,
    Math.round(data.latitude * 1000) / 1000,
    Math.round(data.longitude * 1000) / 1000,
  ].join('|');

  return crypto.createHash('sha256').update(normalized).digest('hex');
}

/**
 * Check for potential duplicate reports within the last 24 hours
 * using geohash proximity and category match.
 *
 * @returns {object|null}  The potential duplicate report, or null.
 */
async function findDuplicate(data, log) {
  const hash = geohash.encode(data.latitude, data.longitude, 6); // ~1.2 km precision
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const { data: candidates } = await supabaseAdmin
    .from('reports')
    .select('id, title, geohash, category, created_at')
    .eq('category', data.category)
    .gte('created_at', since)
    .not('status', 'in', '("rejected","duplicate","archived")')
    .limit(20);

  if (!candidates || candidates.length === 0) return null;

  for (const candidate of candidates) {
    if (candidate.geohash && candidate.geohash.startsWith(hash.slice(0, 5))) {
      log.info(
        { existingId: candidate.id, geohash: hash },
        'Potential duplicate detected',
      );
      return candidate;
    }
  }

  return null;
}

/**
 * Create a new report.
 *
 * @param {object} data  Validated report payload.
 * @param {string|null} userId  Supabase user ID (sub claim).
 * @param {import('pino').Logger} log  Request-scoped logger.
 * @returns {Promise<object>}  The created report row.
 */
async function createReport(data, userId, log) {
  // Idempotency check
  if (data.idempotency_key) {
    const { data: existing } = await supabaseAdmin
      .from('idempotency_keys')
      .select('response_body')
      .eq('key', data.idempotency_key)
      .maybeSingle();

    if (existing) {
      log.info({ idempotency_key: data.idempotency_key }, 'Idempotent replay');
      return existing.response_body;
    }
  }

  // Compute geohash and content hash
  const hash = geohash.encode(data.latitude, data.longitude, 7);
  const contentHash = computeContentHash(data);

  // Check for duplicates
  const dup = await findDuplicate(data, log);

  const row = {
    title: data.title,
    description: data.description || '',
    category: data.category,
    subcategory: data.subcategory || null,
    municipality: data.municipality,
    latitude: data.latitude,
    longitude: data.longitude,
    address: data.address || null,
    image_urls: data.image_url ? [data.image_url] : [],
    status: 'submitted',
    user_id: userId || null,
    geohash: hash,
    content_hash: contentHash,
    duplicate_of: dup ? dup.id : null,
    duplicate_score: dup ? 80 : 0,
  };

  const { data: report, error } = await supabaseAdmin
    .from('reports')
    .insert([row])
    .select()
    .single();

  if (error) {
    log.error({ error }, 'Failed to insert report');
    throw new Error('Failed to create report in database');
  }

  // Store idempotency key
  if (data.idempotency_key) {
    await supabaseAdmin
      .from('idempotency_keys')
      .insert([{
        key: data.idempotency_key,
        endpoint: 'POST /api/v1/reports',
        response_status: 201,
        response_body: report,
      }]);
  }

  // Write audit log
  writeAuditLog({
    action: 'report.created',
    actor_id: userId,
    entity_type: 'report',
    entity_id: report.id,
    metadata: {
      category: data.category,
      municipality: data.municipality,
      has_image: !!data.image_url,
      is_potential_duplicate: !!dup,
    },
  }, log);

  // Write initial status history entry
  await supabaseAdmin
    .from('report_status_history')
    .insert([{
      report_id: report.id,
      old_status: null,
      new_status: 'submitted',
      changed_by: userId || null,
      is_system_action: true,
      reason: 'Report created',
    }]);

  // Fire-and-forget email notification
  notifyMunicipality(report, log).catch((err) => {
    log.error({ err, reportId: report.id }, 'Municipality notification failed');
  });

  return report;
}

/**
 * List reports with optional filters and pagination.
 */
async function listReports(filters) {
  let query = supabaseAdmin
    .from('reports')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(filters.offset, filters.offset + filters.limit - 1);

  if (filters.municipality) query = query.eq('municipality', filters.municipality);
  if (filters.category) query = query.eq('category', filters.category);
  if (filters.status && filters.status !== 'all') query = query.eq('status', filters.status);

  const { data: reports, error, count } = await query;
  if (error) throw new Error('Failed to fetch reports');

  return { reports: reports || [], total: count || 0 };
}

/**
 * Get a single report by ID.
 */
async function getReportById(id) {
  const { data: report, error } = await supabaseAdmin
    .from('reports')
    .select('*')
    .eq('id', id)
    .single();

  if (error || !report) throw new NotFoundError('Report');
  return report;
}

/**
 * Transition a report to a new status, enforcing the state machine.
 * Writes to report_status_history and audit_logs.
 */
async function updateReportStatus(id, newStatus, note, actorId, log) {
  const report = await getReportById(id);
  const allowed = VALID_TRANSITIONS[report.status] || [];

  if (!allowed.includes(newStatus)) {
    throw new ValidationError(
      `Cannot transition from "${report.status}" to "${newStatus}". `
      + `Allowed: ${allowed.join(', ') || 'none (terminal state)'}`,
    );
  }

  const { data: updated, error } = await supabaseAdmin
    .from('reports')
    .update({ status: newStatus })
    .eq('id', id)
    .select()
    .single();

  if (error) {
    log.error({ error }, 'Failed to update report status');
    throw new Error('Failed to update report status');
  }

  // Write status history
  await supabaseAdmin
    .from('report_status_history')
    .insert([{
      report_id: id,
      old_status: report.status,
      new_status: newStatus,
      changed_by: actorId || null,
      reason: note || null,
      is_system_action: false,
    }]);

  // Write audit log
  writeAuditLog({
    action: 'report.status_changed',
    actor_id: actorId,
    entity_type: 'report',
    entity_id: id,
    metadata: {
      old_status: report.status,
      new_status: newStatus,
      note: note || null,
    },
  }, log);

  log.info({ reportId: id, from: report.status, to: newStatus, actorId }, 'Report status updated');
  return updated;
}

module.exports = {
  createReport,
  listReports,
  getReportById,
  updateReportStatus,
  VALID_TRANSITIONS,
};
