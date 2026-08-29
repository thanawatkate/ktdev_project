/**
 * ตั้ง school DB context จาก JWT หรือ schoolCode ใน body (login/activate)
 */
const jwt = require('jsonwebtoken');
const masterDb = require('../utils/school-db-context').getDefaultDb();
const {
  runWithSchoolDbName,
  extractSchoolCodeFromPayload,
} = require('../utils/school-db-context');
const { getSchoolKnex } = require('../utils/school-db.factory');

const EXEMPT_PREFIXES = [
  '/saccapi/setup',
  '/saccapi/internal',
];

function isExempt(path) {
  if (path === '/saccapi' || path === '/saccapi/') return true;
  return EXEMPT_PREFIXES.some((p) => path.startsWith(p));
}

function extractToken(req) {
  if (req.body?.token) return req.body.token;
  const auth = req.headers.authorization;
  if (auth && auth.startsWith('Bearer ')) return auth.slice(7);
  return null;
}

async function resolveSchoolRecord(schoolCode) {
  if (!schoolCode) return null;
  return masterDb('school_tenant')
    .where({ school_code: schoolCode, status: 'active' })
    .first();
}

async function schoolContextMiddleware(req, res, next) {
  if (isExempt(req.originalUrl)) {
    return next();
  }

  try {
    let schoolCode = extractSchoolCodeFromPayload(req.body);

    const token = extractToken(req);
    if (!schoolCode && token) {
      try {
        const payload = jwt.verify(token, process.env.SECRETKEY);
        schoolCode = payload.schoolCode || payload.school_code;
      } catch (_) {
        // token invalid — ปล่อยให้ service ตรวจต่อ
      }
    }

    if (!schoolCode) {
      return next();
    }

    const school = await resolveSchoolRecord(schoolCode);
    if (!school) {
      return res.status(403).json({
        status: 'error',
        message: 'ไม่พบโรงเรียนที่เปิดใช้งานแล้ว หรือรหัสโรงเรียนไม่ถูกต้อง',
      });
    }

    req.schoolCode = school.school_code;
    req.schoolDbName = school.db_name;

    return runWithSchoolDbName(school.db_name, () => next());
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  schoolContextMiddleware,
  resolveSchoolRecord,
  getSchoolKnex,
};
