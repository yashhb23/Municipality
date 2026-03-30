'use strict';

const { supabaseAdmin } = require('../utils/supabaseAdmin');

/**
 * Write an entry to the audit_logs table.
 *
 * @param {object} entry
 * @param {string} entry.action      e.g. 'report.created', 'report.status_changed'
 * @param {string} [entry.actor_id]  UUID of the acting user (null for system).
 * @param {string} [entry.entity_type]  e.g. 'report', 'user'
 * @param {string} [entry.entity_id]    UUID of the affected entity.
 * @param {object} [entry.metadata]     Arbitrary JSON payload with details.
 * @param {import('pino').Logger} [log]
 */
async function writeAuditLog(entry, log) {
  const { error } = await supabaseAdmin
    .from('audit_logs')
    .insert([{
      action: entry.action,
      actor_id: entry.actor_id || null,
      entity_type: entry.entity_type || null,
      entity_id: entry.entity_id || null,
      metadata: entry.metadata || {},
      created_at: new Date().toISOString(),
    }]);

  if (error) {
    if (log) log.error({ error, entry }, 'Failed to write audit log');
  }
}

module.exports = { writeAuditLog };
