const db = require('../../configs/db.config');
const { checkTokenEXP, decodeTokenPayloadSync } = require('../../sacc_login/services/login.service');
const { writeAuditLog } = require('../../sacc_auditlog/auditlog.service');
const { updateUsedAmount } = require('../../sacc_budgetsource/services/budgetsource.service');

async function resolveActor(token, meta = {}) {
  const payload = decodeTokenPayloadSync(token || '');
  if (!payload || !payload.id) return null;
  const user = await db('users').where('id', payload.id).first();
  const groupId = Number(payload.usergroup ?? user?.refusergroup ?? user?.ref_usergroup ?? 0);
  const group = Number.isFinite(groupId) && groupId > 0
    ? await db('usergroup').where('id', groupId).first()
    : null;
  const actorName = meta.userName
    || `${payload.name || ''} ${payload.lastname || ''}`.trim()
    || payload.username
    || null;
  return { userId: payload.id, userName: actorName, groupId, group };
}

async function hasApprovalPermission(actor) {
  if (!actor || !actor.userId) return false;
  if (actor.groupId === 1) return true;
  const groupName = `${actor.group?.nameen || ''} ${actor.group?.nameth || ''}`.toLowerCase();
  if (groupName.includes('admin') || groupName.includes('ผู้ดูแล')) return true;

  const perm = await db('usergroup_permission')
    .where({ usergroup_id: actor.groupId, permission_key: 'approval.manage' })
    .first();
  if (perm) return true;

  const approvePerm = await db('usergroup_permission')
    .where({ usergroup_id: actor.groupId, permission_key: 'approval.approve' })
    .first();
  return Boolean(approvePerm);
}

async function hasSubmitPermission(actor) {
  if (!actor || !actor.userId) return false;
  if (actor.groupId === 1) return true;
  const groupName = `${actor.group?.nameen || ''} ${actor.group?.nameth || ''}`.toLowerCase();
  if (groupName.includes('admin') || groupName.includes('ผู้ดูแล')) return true;

  const keys = ['approval.view', 'nav.expense', 'nav.expense_req'];
  for (const key of keys) {
    const perm = await db('usergroup_permission')
      .where({ usergroup_id: actor.groupId, permission_key: key })
      .first();
    if (perm) return true;
  }
  return false;
}

async function hasRejectPermission(actor) {
  if (!actor || !actor.userId) return false;
  if (actor.groupId === 1) return true;
  const groupName = `${actor.group?.nameen || ''} ${actor.group?.nameth || ''}`.toLowerCase();
  if (groupName.includes('admin') || groupName.includes('ผู้ดูแล')) return true;

  const managePerm = await db('usergroup_permission')
    .where({ usergroup_id: actor.groupId, permission_key: 'approval.manage' })
    .first();
  if (managePerm) return true;

  const rejectPerm = await db('usergroup_permission')
    .where({ usergroup_id: actor.groupId, permission_key: 'approval.reject' })
    .first();
  return Boolean(rejectPerm);
}

/**
 * ส่งใบขอเบิกเข้ากระบวนการอนุมัติ (draft → pending)
 */
async function submit(id, bodyData, meta = {}) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  const actor = await resolveActor(bodyData.token, meta);
  if (!actor) return { status: 'error', message: 'ไม่พบผู้ใช้งานจาก token' };
  if (!(await hasSubmitPermission(actor))) {
    return { status: 'error', message: 'ไม่มีสิทธิ์ส่งขออนุมัติรายการ' };
  }

  const req = await db('expensereq').where('id', id).first();
  if (!req) return { status: 'error', message: 'ไม่พบใบขอเบิก' };
  if (req.approval_status !== 'draft') return { status: 'error', message: 'สถานะต้องเป็น draft เท่านั้น' };

  await db('expensereq').where('id', id).update({
    approval_status: 'pending',
    updated: new Date(),
  });

  await db('approval_log').insert({
    ref_table: 'expensereq',
    ref_id: parseInt(id),
    action: 'submit',
    actor_id: actor.userId,
    actor_name: actor.userName,
    note: bodyData.note || null,
  });

  await writeAuditLog({ tablename: 'expensereq', record_id: parseInt(id), action: 'UPDATE',
    old_data: JSON.stringify({ approval_status: 'draft' }),
    new_data: JSON.stringify({ approval_status: 'pending' }),
    user_id: actor.userId, user_name: actor.userName, ip_address: meta.ip });

  return { status: 'successfully', message: 'ส่งขออนุมัติเรียบร้อยแล้ว' };
}

/**
 * อนุมัติใบขอเบิก (pending → approved)
 */
async function approve(id, bodyData, meta = {}) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  const actor = await resolveActor(bodyData.token, meta);
  if (!actor) return { status: 'error', message: 'ไม่พบผู้ใช้งานจาก token' };
  if (!(await hasApprovalPermission(actor))) {
    return { status: 'error', message: 'ไม่มีสิทธิ์อนุมัติรายการ' };
  }

  const req = await db('expensereq').where('id', id).first();
  if (!req) return { status: 'error', message: 'ไม่พบใบขอเบิก' };
  if (req.approval_status !== 'pending') return { status: 'error', message: 'สถานะต้องเป็น pending เท่านั้น' };
  const latestSubmitLog = await db('approval_log')
    .where({ ref_table: 'expensereq', ref_id: parseInt(id), action: 'submit' })
    .orderBy('created', 'desc')
    .first();
  if (latestSubmitLog && Number(latestSubmitLog.actor_id) === Number(actor.userId)) {
    return { status: 'error', message: 'ผู้ส่งขออนุมัติไม่สามารถอนุมัติรายการเดียวกันได้' };
  }

  const now = new Date();
  await db('expensereq').where('id', id).update({
    approval_status: 'approved',
    approved_by: actor.userId,
    approved_at: now,
    updated: now,
  });

  await db('approval_log').insert({
    ref_table: 'expensereq',
    ref_id: parseInt(id),
    action: 'approve',
    actor_id: actor.userId,
    actor_name: actor.userName,
    note: bodyData.note || null,
  });

  await writeAuditLog({ tablename: 'expensereq', record_id: parseInt(id), action: 'UPDATE',
    old_data: JSON.stringify({ approval_status: 'pending' }),
    new_data: JSON.stringify({ approval_status: 'approved', approved_by: actor.userId }),
    user_id: actor.userId, user_name: actor.userName, ip_address: meta.ip });

  return { status: 'successfully', message: 'อนุมัติใบขอเบิกเรียบร้อยแล้ว' };
}

/**
 * ปฏิเสธใบขอเบิก (pending → rejected)
 */
async function reject(id, bodyData, meta = {}) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  if (!bodyData.reject_reason) return { status: 'error', message: 'กรุณาระบุเหตุผลที่ไม่อนุมัติ' };
  const actor = await resolveActor(bodyData.token, meta);
  if (!actor) return { status: 'error', message: 'ไม่พบผู้ใช้งานจาก token' };
  if (!(await hasRejectPermission(actor))) {
    return { status: 'error', message: 'ไม่มีสิทธิ์อนุมัติรายการ' };
  }

  const req = await db('expensereq').where('id', id).first();
  if (!req) return { status: 'error', message: 'ไม่พบใบขอเบิก' };
  if (req.approval_status !== 'pending') return { status: 'error', message: 'สถานะต้องเป็น pending เท่านั้น' };
  const latestSubmitLog = await db('approval_log')
    .where({ ref_table: 'expensereq', ref_id: parseInt(id), action: 'submit' })
    .orderBy('created', 'desc')
    .first();
  if (latestSubmitLog && Number(latestSubmitLog.actor_id) === Number(actor.userId)) {
    return { status: 'error', message: 'ผู้ส่งขออนุมัติไม่สามารถปฏิเสธรายการเดียวกันได้' };
  }

  await db('expensereq').where('id', id).update({
    approval_status: 'rejected',
    reject_reason: bodyData.reject_reason,
    approved_by: actor.userId,
    approved_at: new Date(),
    updated: new Date(),
  });

  await db('approval_log').insert({
    ref_table: 'expensereq',
    ref_id: parseInt(id),
    action: 'reject',
    actor_id: actor.userId,
    actor_name: actor.userName,
    note: bodyData.reject_reason,
  });

  await writeAuditLog({ tablename: 'expensereq', record_id: parseInt(id), action: 'UPDATE',
    old_data: JSON.stringify({ approval_status: 'pending' }),
    new_data: JSON.stringify({ approval_status: 'rejected', reject_reason: bodyData.reject_reason }),
    user_id: actor.userId, user_name: actor.userName, ip_address: meta.ip });

  return { status: 'successfully', message: 'ปฏิเสธใบขอเบิกเรียบร้อยแล้ว' };
}

/**
 * ดึงรายการใบขอเบิกตามสถานะ
 */
async function getByStatus(status) {
  let q = db('expensereq as r')
    .leftJoin('member as m', 'r.refmember', 'm.id')
    .leftJoin('budgetsource as b', 'r.refbudgetsource', 'b.id')
    .leftJoin('users as u', 'r.approved_by', 'u.id')
    .select(
      'r.*',
      db.raw("CONCAT(COALESCE(m.name,''), ' ', COALESCE(m.lastname,'')) as member_name"),
      'b.name as budget_source_name',
      'b.code as budget_source_code',
      db.raw("CONCAT(u.name, ' ', u.lastname) as approver_name"),
    )
    .orderBy('r.created', 'desc');

  if (status && status !== 'all') q = q.where('r.approval_status', status);

  const rows = await q;
  return { data: rows };
}

/**
 * ดึงประวัติการอนุมัติของใบขอเบิก
 */
async function getApprovalLog(refTable, refId) {
  const rows = await db('approval_log')
    .where({ ref_table: refTable, ref_id: parseInt(refId) })
    .orderBy('created', 'asc');
  return { data: rows };
}

module.exports = { submit, approve, reject, getByStatus, getApprovalLog };
