const db = require('../configs/db.config');
const {
  checkTokenEXP,
  decodeTokenPayloadSync,
} = require('../sacc_login/services/login.service');

function extractToken(req) {
  const auth = req.headers.authorization;
  if (auth && auth.startsWith('Bearer ')) return auth.slice(7);
  if (req.query?.token) return req.query.token;
  if (req.body?.token) return req.body.token;
  return null;
}

async function userHasReportAccess(payload) {
  if (!payload || payload.id == null) return false;

  let groupId = payload.usergroup ?? payload.userGroup;
  if (groupId == null || groupId === '') {
    const user = await db('users').where('id', payload.id).first();
    groupId = user?.refusergroup ?? user?.ref_usergroup;
  }

  const gid = Number(groupId);
  if (!Number.isFinite(gid)) return false;

  const group = await db('usergroup').where('id', gid).first();
  const groupName = `${group?.nameen || ''} ${group?.nameTH || ''} ${group?.name || ''}`
    .toLowerCase();
  if (groupName.includes('admin') || groupName.includes('ผู้ดูแล')) return true;

  const row = await db('usergroup_permission')
    .where({ usergroup_id: gid, permission_key: 'nav.reports' })
    .first();
  return Boolean(row);
}

async function requireReportAccess(req, res, next) {
  try {
    const token = extractToken(req);
    if (!token || checkTokenEXP(token)) {
      return res.status(401).json({
        success: false,
        message: 'Token หมดอายุหรือไม่ถูกต้อง',
      });
    }

    const payload = decodeTokenPayloadSync(token);
    if (!(await userHasReportAccess(payload))) {
      return res.status(403).json({
        success: false,
        message: 'ไม่มีสิทธิ์ดูรายงานการเงิน',
      });
    }

    req.auth = payload;
    return next();
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  extractToken,
  requireReportAccess,
  userHasReportAccess,
};
