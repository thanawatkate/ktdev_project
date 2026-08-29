/**
 * เรียก API ระบบออนไลน์ (backend หลัก) เพื่อสร้าง DB โรงเรียน + admin
 */
require('dotenv').config();

function onlineApiRoot() {
  const raw = process.env.ONLINE_API_BASE || 'http://localhost:3800/saccapi/';
  return raw.endsWith('/') ? raw : `${raw}/`;
}

async function provisionSchoolOnOnlineApi(payload) {
  const secret = process.env.INTERNAL_API_SECRET;
  if (!secret) {
    throw new Error('INTERNAL_API_SECRET ไม่ได้ตั้งใน registry .env');
  }

  const url = `${onlineApiRoot()}internal/school/provision`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Internal-Secret': secret,
    },
    body: JSON.stringify(payload),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.success === false) {
    throw new Error(data.message || `Online provision failed HTTP ${res.status}`);
  }
  return data;
}

async function fetchLoginToken({ schoolCode, username, password }) {
  const url = `${onlineApiRoot()}login/token`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password, schoolCode }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.token) {
    return null;
  }
  return data.token;
}

module.exports = {
  provisionSchoolOnOnlineApi,
  fetchLoginToken,
};
