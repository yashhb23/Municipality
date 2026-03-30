'use strict';

const nodemailer = require('nodemailer');

const MUNICIPALITY_EMAILS = {
  'Port Louis': 'portlouis@municipal.mu',
  'Curepipe': 'curepipe@municipal.mu',
  'Quatre Bornes': 'quatrebornes@municipal.mu',
  'Beau Bassin-Rose Hill': 'beaubassin@municipal.mu',
  'Vacoas-Phoenix': 'vacoas@municipal.mu',
  'Mahébourg': 'mahebourg@municipal.mu',
  'Flacq': 'flacq@municipal.mu',
  'Goodlands': 'goodlands@municipal.mu',
  'Triolet': 'triolet@municipal.mu',
  'Black River': 'blackriver@municipal.mu',
};

let transporter = null;

/** Lazily create the nodemailer transporter so tests can stub env vars. */
function getTransporter() {
  if (!transporter && process.env.EMAIL_USER && process.env.EMAIL_PASS) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });
  }
  return transporter;
}

/**
 * Send an email notification to the appropriate municipality
 * when a new report is created.
 *
 * @param {object} report  The full report row from the database.
 * @param {import('pino').Logger} [log]  Optional logger instance.
 * @returns {Promise<boolean>}  true if sent (or logged), false if skipped.
 */
async function notifyMunicipality(report, log) {
  const to = MUNICIPALITY_EMAILS[report.municipality];
  if (!to) {
    if (log) log.warn({ municipality: report.municipality }, 'No email mapped for municipality');
    return false;
  }

  const subject = `FixMo Report: ${report.category} in ${report.municipality}`;
  const text = [
    'Hello,',
    '',
    'A new civic issue was reported by a resident in your region via the FixMo app.',
    '',
    `Location: ${report.address || `${report.latitude}, ${report.longitude}`}`,
    `Category: ${report.category}`,
    `Title: ${report.title}`,
    `Description: ${report.description || '(none)'}`,
    `Date: ${new Date(report.created_at).toLocaleDateString()}`,
    report.image_url ? `Photo: ${report.image_url}` : 'Photo: No image attached',
    '',
    `Status: ${(report.status || 'pending').toUpperCase()}`,
    `Report ID: ${report.id}`,
    '',
    'Thank you for making Mauritius better!',
    'FixMo Team',
  ].join('\n');

  const mail = getTransporter();
  if (mail) {
    await mail.sendMail({
      from: process.env.EMAIL_USER,
      to,
      subject,
      text,
      html: text.replace(/\n/g, '<br>'),
    });
    if (log) log.info({ reportId: report.id, to }, 'Municipality email sent');
  } else {
    if (log) log.info({ reportId: report.id, to, subject }, 'Email not configured — logged only');
  }

  return true;
}

module.exports = { notifyMunicipality, MUNICIPALITY_EMAILS };
