const crypto = require('crypto');
const bcrypt = require('bcrypt');
const db = require('../utils/db');
const {
  provisionSchoolOnOnlineApi,
  fetchLoginToken,
} = require('./online_client');

const KEY_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const STANDARD_DAYS_DEFAULT = 365;

function normalizeLicenseKey(raw) {
  return String(raw || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .replace(/^SACC/, '');
}

function formatLicenseKey(normalized12) {
  const p = normalized12.padEnd(12, '0').slice(0, 12);
  return `SACC-${p.slice(0, 4)}-${p.slice(4, 8)}-${p.slice(8, 12)}`;
}

function generateLicenseKey() {
  const bytes = crypto.randomBytes(9);
  let raw = '';
  for (let i = 0; i < 12; i += 1) {
    raw += KEY_ALPHABET[bytes[i % bytes.length] % KEY_ALPHABET.length];
  }
  return formatLicenseKey(raw);
}

function keyHintFromPlain(plainKey) {
  const n = normalizeLicenseKey(plainKey);
  return n.length >= 4 ? `...-${n.slice(-4)}` : null;
}

function slugSchoolCode(name) {
  const base = String(name || 'school')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 24) || 'school';
  const suffix = crypto.randomBytes(2).toString('hex');
  return `${base}-${suffix}`;
}

function schoolDbName(schoolCode) {
  const safe = String(schoolCode || '')
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, '_')
    .slice(0, 48);
  return `saccm_${safe}`;
}

async function hashLicenseKey(normalized) {
  return bcrypt.hash(`SACC${normalized}`, 10);
}

async function verifyLicenseKey(rawKey, hash) {
  return bcrypt.compare(`SACC${normalizeLicenseKey(rawKey)}`, hash);
}

async function findLicenseByKey(rawKey) {
  const rows = await db('school_license').whereIn('status', ['pending', 'active']);
  for (const row of rows) {
    // eslint-disable-next-line no-await-in-loop
    const ok = await verifyLicenseKey(rawKey, row.license_key_hash);
    if (ok) return row;
  }
  return null;
}

async function logActivation({
  licenseId,
  schoolCode,
  deviceId,
  platform,
  event,
  result,
  message,
  clientIp,
}) {
  await db('license_activation_log').insert({
    ref_school_license: licenseId || null,
    school_code: schoolCode || null,
    device_id: deviceId || null,
    platform: platform || null,
    event,
    result: result || null,
    message: message || null,
    client_ip: clientIp || null,
  });
}

async function generateLicense({
  schoolName,
  maxDevices = 3,
  expiresInDays,
  licenseKind = 'offline',
  note,
  issuedBy,
}) {
  if (!schoolName || !String(schoolName).trim()) {
    return { status: 'error', message: 'กรุณาระบุชื่อโรงเรียน' };
  }

  const kind = licenseKind === 'online' ? 'online' : 'offline';
  const days = expiresInDays != null
    ? parseInt(expiresInDays, 10)
    : STANDARD_DAYS_DEFAULT;

  const plainKey = generateLicenseKey();
  const normalized = normalizeLicenseKey(plainKey);
  const schoolCode = slugSchoolCode(schoolName);
  const dbName = schoolDbName(schoolCode);
  const hash = await hashLicenseKey(normalized);
  const hint = keyHintFromPlain(plainKey);
  const expiresAt = days > 0
    ? new Date(Date.now() + days * 86400000)
    : null;

  const [id] = await db('school_license').insert({
    school_code: schoolCode,
    school_name: String(schoolName).trim(),
    license_key_hash: hash,
    db_name: dbName,
    license_kind: kind,
    status: 'pending',
    max_devices: Math.max(1, parseInt(maxDevices, 10) || 3),
    expires_at: expiresAt,
    note: note || null,
    issued_by: issuedBy || null,
    key_hint: hint,
  });

  await db('license_issue_log').insert({
    ref_school_license: id,
    school_code: schoolCode,
    school_name: String(schoolName).trim(),
    license_kind: kind,
    max_devices: Math.max(1, parseInt(maxDevices, 10) || 3),
    expires_at: expiresAt,
    issued_by: issuedBy || null,
    key_hint: hint,
    note: note || null,
  });

  return {
    status: 'success',
    id,
    schoolCode,
    schoolName: String(schoolName).trim(),
    licenseKey: plainKey,
    licenseKind: kind,
    maxDevices: Math.max(1, parseInt(maxDevices, 10) || 3),
    expiresAt,
    dbName,
  };
}

async function countDevices(licenseId) {
  const row = await db('school_device')
    .where({ ref_school_license: licenseId })
    .count('id as c')
    .first();
  return parseInt(row?.c, 10) || 0;
}

async function touchDevice(licenseId, deviceId, deviceLabel, platform) {
  const existing = await db('school_device')
    .where({ ref_school_license: licenseId, device_id: deviceId })
    .first();

  if (existing) {
    await db('school_device')
      .where({ id: existing.id })
      .update({
        device_label: deviceLabel || existing.device_label,
        platform: platform || existing.platform,
        last_seen: db.fn.now(),
      });
    return existing;
  }

  const [id] = await db('school_device').insert({
    ref_school_license: licenseId,
    device_id: deviceId,
    device_label: deviceLabel || null,
    platform: platform || null,
  });
  return { id, device_id: deviceId };
}

async function activateLicense(body, clientIp) {
  const {
    licenseKey,
    deviceId,
    deviceLabel,
    platform,
    adminUsername,
    adminPassword,
    adminName,
    adminLastname,
    adminEmail,
  } = body;

  const fail = async (msg, licenseRow) => {
    await logActivation({
      licenseId: licenseRow?.id,
      schoolCode: licenseRow?.school_code,
      deviceId,
      platform,
      event: 'activate_fail',
      result: 'fail',
      message: msg,
      clientIp,
    });
    return { status: 'error', message: msg };
  };

  if (!licenseKey || !deviceId) {
    return fail('กรุณาระบุรหัสเปิดใช้งานและรหัสเครื่อง');
  }
  if (!adminUsername || !adminPassword || adminPassword.length < 6) {
    return fail('กรุณาระบุชื่อผู้ใช้และรหัสผ่านอย่างน้อย 6 ตัว');
  }

  const license = await findLicenseByKey(licenseKey);
  if (!license) {
    return fail('รหัสเปิดใช้งานไม่ถูกต้องหรือถูกยกเลิกแล้ว');
  }
  if (license.status === 'revoked') {
    return fail('รหัสเปิดใช้งานถูกยกเลิก', license);
  }
  if (license.expires_at && new Date(license.expires_at) < new Date()) {
    await db('school_license').where({ id: license.id }).update({ status: 'expired' });
    return fail('รหัสเปิดใช้งานหมดอายุ — ติดต่อผู้ให้บริการ', license);
  }

  const deviceCount = await countDevices(license.id);
  const alreadyRegistered = await db('school_device')
    .where({ ref_school_license: license.id, device_id: deviceId })
    .first();

  if (!alreadyRegistered && deviceCount >= license.max_devices) {
    return fail(`จำนวนเครื่องเต็มแล้ว (สูงสุด ${license.max_devices} เครื่อง)`, license);
  }

  const isOnlineProduct = license.license_kind === 'online';

  try {
    if (license.status === 'pending') {
      if (isOnlineProduct) {
        await provisionSchoolOnOnlineApi({
          schoolCode: license.school_code,
          dbName: license.db_name,
          schoolName: license.school_name,
          adminUsername,
          adminPassword,
          adminName,
          adminLastname,
          adminEmail,
        });
      }
      await db('school_license')
        .where({ id: license.id })
        .update({
          status: 'active',
          activated_at: db.fn.now(),
          updated: db.fn.now(),
        });
      license.status = 'active';
    }

    await touchDevice(license.id, deviceId, deviceLabel, platform);

    let token = '';
    if (isOnlineProduct) {
      token = await fetchLoginToken({
        schoolCode: license.school_code,
        username: adminUsername,
        password: adminPassword,
      });
      if (!token) {
        return fail('สร้างบัญชีสำเร็จแต่เข้าสู่ระบบไม่ได้ — ตรวจรหัสผ่าน', license);
      }
    }

    await logActivation({
      licenseId: license.id,
      schoolCode: license.school_code,
      deviceId,
      platform,
      event: 'activate_success',
      result: 'success',
      message: `kind=${license.license_kind}`,
      clientIp,
    });

    return {
      status: 'success',
      message: isOnlineProduct
        ? 'เปิดใช้งานออนไลน์+ออฟไลน์สำเร็จ'
        : 'เปิดใช้งานออฟไลน์สำเร็จ',
      schoolCode: license.school_code,
      schoolName: license.school_name,
      licenseKind: license.license_kind,
      canSync: isOnlineProduct,
      expiresAt: license.expires_at,
      dbName: license.db_name,
      token,
      adminUsername,
    };
  } catch (err) {
    return fail(err.message || 'เปิดใช้งานไม่สำเร็จ', license);
  }
}

async function heartbeat(body, clientIp) {
  const { schoolCode, deviceId, platform } = body;
  if (!schoolCode || !deviceId) {
    return { status: 'error', message: 'กรุณาระบุ schoolCode และ deviceId' };
  }

  const license = await db('school_license')
    .where({ school_code: schoolCode, status: 'active' })
    .first();

  if (!license) {
    return { status: 'error', message: 'ไม่พบโรงเรียนที่เปิดใช้งาน' };
  }

  await touchDevice(license.id, deviceId, null, platform);
  await logActivation({
    licenseId: license.id,
    schoolCode,
    deviceId,
    platform,
    event: 'heartbeat',
    result: 'success',
    clientIp,
  });

  return { status: 'success', lastSeen: new Date().toISOString() };
}

async function issueServerToken(body) {
  const {
    schoolCode,
    school_code: schoolCodeSnake,
    username,
    password,
  } = body || {};
  const resolvedSchoolCode = (schoolCode || schoolCodeSnake || '').toString().trim();
  const resolvedUsername = (username || '').toString().trim();

  if (!resolvedSchoolCode || !resolvedUsername || !password) {
    return { status: 'error', message: 'กรุณาระบุ schoolCode, username และ password' };
  }

  const license = await db('school_license')
    .where({ school_code: resolvedSchoolCode })
    .first();
  if (!license) {
    return { status: 'error', message: 'ไม่พบข้อมูลโรงเรียน' };
  }
  const expired = license.expires_at && new Date(license.expires_at) < new Date();
  if (license.status !== 'active' || expired) {
    return { status: 'error', message: 'License ไม่พร้อมใช้งานหรือหมดอายุ' };
  }
  if (license.license_kind !== 'online') {
    return { status: 'error', message: 'แพ็กเกจนี้ไม่รองรับการซิงก์ออนไลน์' };
  }

  const token = await fetchLoginToken({
    schoolCode: resolvedSchoolCode,
    username: resolvedUsername,
    password,
  });
  if (!token) {
    return { status: 'error', message: 'เข้าสู่ระบบออนไลน์ไม่สำเร็จ' };
  }

  return { status: 'success', token, accessToken: token };
}

async function listLicenses() {
  const rows = await db('school_license')
    .select(
      'id', 'school_code', 'school_name', 'license_kind', 'status',
      'max_devices', 'expires_at', 'activated_at', 'created', 'db_name',
      'issued_by', 'key_hint',
    )
    .orderBy('id', 'desc');

  const withDevices = await Promise.all(
    rows.map(async (r) => ({
      ...r,
      devicesUsed: await countDevices(r.id),
    })),
  );

  return { status: 'success', rows: withDevices };
}

async function listIssueLogs(limit = 100) {
  const rows = await db('license_issue_log')
    .orderBy('id', 'desc')
    .limit(Math.min(limit, 500));
  return { status: 'success', rows };
}

async function listActivationLogs({ schoolCode, limit = 100 } = {}) {
  let q = db('license_activation_log').orderBy('id', 'desc');
  if (schoolCode) q = q.where({ school_code: schoolCode });
  const rows = await q.limit(Math.min(limit, 500));
  return { status: 'success', rows };
}

async function revokeLicense({ schoolCode, note }) {
  if (!schoolCode) return { status: 'error', message: 'กรุณาระบุ schoolCode' };
  const license = await db('school_license').where({ school_code: schoolCode }).first();
  if (!license) return { status: 'error', message: 'ไม่พบโรงเรียน' };
  await db('school_license')
    .where({ id: license.id })
    .update({ status: 'revoked', note: note || license.note, updated: db.fn.now() });
  return { status: 'success', message: 'ยกเลิกรหัสแล้ว', schoolCode };
}

async function validateLicense(body) {
  const { licenseKey, deviceId } = body;
  if (!licenseKey) {
    return { status: 'error', message: 'กรุณาระบุรหัสเปิดใช้งาน' };
  }

  const license = await findLicenseByKey(licenseKey);
  if (!license) {
    return { status: 'success', valid: false, message: 'รหัสไม่ถูกต้อง' };
  }

  const deviceCount = await countDevices(license.id);
  const registered = deviceId
    ? await db('school_device')
      .where({ ref_school_license: license.id, device_id: deviceId })
      .first()
    : null;

  const expired = license.expires_at && new Date(license.expires_at) < new Date();

  return {
    status: 'success',
    valid: true,
    schoolCode: license.status === 'active' ? license.school_code : null,
    schoolName: license.school_name,
    licenseKind: license.license_kind,
    licenseStatus: license.status,
    expired,
    expiresAt: license.expires_at,
    devicesUsed: deviceCount,
    maxDevices: license.max_devices,
    canActivate: license.status !== 'revoked'
      && !expired
      && (registered || deviceCount < license.max_devices),
    alreadyRegistered: !!registered,
  };
}

async function getSchoolLicenseStatus({ schoolCode, deviceId, platform }) {
  if (!schoolCode) return { status: 'error', message: 'กรุณาระบุ schoolCode' };
  const license = await db('school_license').where({ school_code: schoolCode }).first();
  if (!license) return { status: 'error', message: 'ไม่พบข้อมูลโรงเรียน' };

  const devicesUsed = await countDevices(license.id);
  const devices = await db('school_device')
    .where({ ref_school_license: license.id })
    .select('device_id', 'device_label', 'platform', 'first_seen', 'last_seen')
    .orderBy('last_seen', 'desc');

  let thisDeviceRegistered = false;
  if (deviceId) {
    thisDeviceRegistered = devices.some((d) => d.device_id === deviceId);
    if (thisDeviceRegistered) {
      await touchDevice(license.id, deviceId, null, platform).catch(() => {});
    }
  }

  const expired = license.expires_at && new Date(license.expires_at) < new Date();

  return {
    status: 'success',
    schoolCode: license.school_code,
    schoolName: license.school_name,
    licenseKind: license.license_kind,
    licenseStatus: license.status,
    expired,
    expiresAt: license.expires_at,
    devicesUsed,
    maxDevices: license.max_devices,
    thisDeviceRegistered,
    devices,
    canSync: license.license_kind === 'online'
      && license.status === 'active'
      && !expired,
  };
}

module.exports = {
  generateLicense,
  activateLicense,
  validateLicense,
  heartbeat,
  issueServerToken,
  listLicenses,
  listIssueLogs,
  listActivationLogs,
  revokeLicense,
  getSchoolLicenseStatus,
  findLicenseByKey,
  STANDARD_DAYS_DEFAULT,
};
