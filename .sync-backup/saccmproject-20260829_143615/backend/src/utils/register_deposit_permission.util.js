const db = require('../configs/db.config');
const { checkTokenEXP, decodeTokenPayloadSync } = require('../sacc_login/services/login.service');

const PERM = {
  view: 'register.deposit.view',
  create: 'register.deposit.create',
  update: 'register.deposit.update',
  settle: 'register.deposit.settle',
  delete: 'register.deposit.delete',
};

async function resolveActor(token, meta = {}) {
  const payload = decodeTokenPayloadSync(token || '');
  if (!payload || !payload.id) return null;
  const user = await db('users').where('id', payload.id).first();
  const groupId = Number(payload.usergroup ?? user?.refusergroup ?? user?.ref_usergroup ?? 0);
  const group =
    Number.isFinite(groupId) && groupId > 0
      ? await db('usergroup').where('id', groupId).first()
      : null;
  const actorName =
    meta.userName ||
    `${payload.name || ''} ${payload.lastname || ''}`.trim() ||
    payload.username ||
    null;
  return { userId: payload.id, userName: actorName, groupId, group };
}

async function isAdminGroup(actor) {
  if (!actor) return false;
  if (actor.groupId === 1) return true;
  const groupName = `${actor.group?.nameen || ''} ${actor.group?.nameth || ''}`.toLowerCase();
  return groupName.includes('admin') || groupName.includes('ผู้ดูแล');
}

async function hasPermission(actor, permissionKey) {
  if (!actor || !actor.groupId) return false;
  if (await isAdminGroup(actor)) return true;
  const perm = await db('usergroup_permission')
    .where({ usergroup_id: actor.groupId, permission_key: permissionKey })
    .first();
  return Boolean(perm);
}

async function assertDepositPermission(body, meta, permissionKey) {
  if (!body?.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(body.token)) return { status: 'error', message: 'Token exp' };
  const actor = await resolveActor(body.token, meta);
  if (!actor) return { status: 'error', message: 'ไม่พบผู้ใช้งานจาก token' };
  if (!(await hasPermission(actor, permissionKey))) {
    return { status: 'error', message: 'ไม่มีสิทธิ์ดำเนินการทะเบียนเงินประกัน/ภาษีหัก ณ ที่จ่าย' };
  }
  return null;
}

module.exports = {
  PERM,
  resolveActor,
  hasPermission,
  assertDepositPermission,
};
