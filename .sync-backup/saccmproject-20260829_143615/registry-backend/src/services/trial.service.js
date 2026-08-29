const crypto = require('crypto');
const db = require('../utils/db');

const DEFAULT_TRIAL_DAYS = Math.max(1, parseInt(process.env.TRIAL_DAYS || '90', 10) || 90);
const DAY_MS = 86400000;

function normalizeFingerprint(value) {
  return String(value || '')
    .trim()
    .replace(/[^a-zA-Z0-9._-]/g, '')
    .slice(0, 128);
}

/**
 * เซ็น payload ด้วย HMAC-SHA256 (server เป็นเจ้าของ secret)
 * client เก็บไว้เป็นหลักฐานว่าค่าวันหมดอายุมาจาก server จริง
 * และให้ server ตรวจซ้ำตอน revalidate ได้
 */
function signPayload(payload) {
  const secret = process.env.TRIAL_SIGNING_SECRET || '';
  if (!secret) return null;
  const data = JSON.stringify(payload);
  return crypto.createHmac('sha256', secret).update(data).digest('base64url');
}

function buildResult(row) {
  const startedAt = new Date(row.trial_started_at);
  const days = row.trial_days;
  const expiresAt = new Date(startedAt.getTime() + days * DAY_MS);
  const now = new Date();
  const payload = {
    fingerprint: row.fingerprint,
    startedAt: startedAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
    days,
  };
  return {
    status: 'success',
    ...payload,
    expired: now > expiresAt,
    serverTime: now.toISOString(),
    signature: signPayload(payload),
  };
}

/**
 * เปิด/ดึง trial ต่อ fingerprint — วันเริ่มถูกตั้งครั้งแรกครั้งเดียว
 * เรียกซ้ำกี่ครั้งก็คืนวันเริ่มเดิม (กัน reset วันทดลอง)
 */
async function startTrial(body, clientIp) {
  const fingerprint = normalizeFingerprint(body && body.fingerprint);
  const platform = body && body.platform ? String(body.platform).slice(0, 32) : null;
  if (!fingerprint) {
    return { status: 'error', message: 'กรุณาระบุ fingerprint' };
  }

  let row = await db('trial_registration').where({ fingerprint }).first();
  if (!row) {
    await db('trial_registration').insert({
      fingerprint,
      platform,
      trial_started_at: db.fn.now(),
      trial_days: DEFAULT_TRIAL_DAYS,
      last_seen: db.fn.now(),
      client_ip: clientIp || null,
    });
    row = await db('trial_registration').where({ fingerprint }).first();
  } else {
    await db('trial_registration')
      .where({ id: row.id })
      .update({ last_seen: db.fn.now(), client_ip: clientIp || null });
  }

  return buildResult(row);
}

module.exports = {
  startTrial,
  normalizeFingerprint,
  signPayload,
  DEFAULT_TRIAL_DAYS,
};
