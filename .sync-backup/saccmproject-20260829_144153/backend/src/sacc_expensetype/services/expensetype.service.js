const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

const tableName = 'expensetype';

function parsePositiveInt(raw) {
  if (typeof raw === 'undefined' || raw === null || raw === '') {
    return null;
  }
  const n = Number.parseInt(String(raw), 10);
  return Number.isInteger(n) && n > 0 ? n : null;
}

async function resolveRefDefaultBudgetSource(bodyData) {
  const id = parsePositiveInt(
    bodyData.refdefaultbudgetsource ?? bodyData.refDefaultBudgetSource,
  );
  if (!id) {
    return { ok: false, message: 'ต้องระบุ refdefaultbudgetsource (แหล่งเงินเริ่มต้น) เป็นตัวเลขบวก' };
  }
  const bs = await db('budgetsource').where('id', id).first();
  if (!bs) {
    return { ok: false, message: 'ไม่พบแหล่งเงินที่ระบุ (refdefaultbudgetsource)' };
  }
  return { ok: true, id };
}

async function getMultiple(page = 1) {
  const safePage = Number.parseInt(page, 10) || 1;
  const offset = helper.getOffset(safePage, config.listPerPage);
  const rows = await db(tableName)
    .select('*')
    .orderBy('sort', 'asc')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);

  return {
    data: helper.emptyOrRows(rows),
    meta: { page: safePage },
  };
}

function normalizeUseFlag(raw) {
  if (typeof raw === 'undefined' || raw === null || raw === '') {
    return undefined;
  }
  const val = String(raw).toUpperCase();
  return val === 'N' ? 'N' : 'Y';
}

async function create(bodyData = {}) {
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp' };
  }

  const code = (bodyData.code || '').toString().trim();
  const name = (bodyData.name || '').toString().trim();
  if (!code) return { status: 'error', message: 'code require' };
  if (!name) return { status: 'error', message: 'name require' };

  const resolvedBs = await resolveRefDefaultBudgetSource(bodyData);
  if (!resolvedBs.ok) {
    return { status: 'error', message: resolvedBs.message };
  }

  const existing = await db(tableName).where('code', code).first();
  if (existing) {
    return { status: 'error', message: 'รหัสประเภทนี้มีในระบบแล้ว' };
  }

  const payload = {
    code,
    name,
    remark: (bodyData.remark || '').toString().trim(),
    sort: Number.parseInt(bodyData.sort, 10) || 0,
    use: normalizeUseFlag(bodyData.use) || 'Y',
    refdefaultbudgetsource: resolvedBs.id,
  };

  const result = await db(tableName).insert(payload);
  const createdId = Array.isArray(result) ? result[0] : result;
  if (createdId > 0) {
    return {
      status: 'successfully',
      message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
      lastid: createdId,
    };
  }
  return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
}

async function update(id, bodyData = {}) {
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp' };
  }

  if (!id) {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }
  const existing = await db(tableName).where('id', id).first();
  if (!existing) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }

  const updates = {};
  if (typeof bodyData.code !== 'undefined') {
    const code = String(bodyData.code).trim();
    if (!code) return { status: 'error', message: 'code require' };
    const duplicated = await db(tableName)
      .where('code', code)
      .andWhereNot('id', id)
      .first();
    if (duplicated) {
      return { status: 'error', message: 'รหัสประเภทนี้มีในระบบแล้ว' };
    }
    updates.code = code;
  }
  if (typeof bodyData.name !== 'undefined') {
    const name = String(bodyData.name).trim();
    if (!name) return { status: 'error', message: 'name require' };
    updates.name = name;
  }
  if (typeof bodyData.remark !== 'undefined') {
    updates.remark = String(bodyData.remark || '').trim();
  }
  if (typeof bodyData.sort !== 'undefined') {
    updates.sort = Number.parseInt(bodyData.sort, 10) || 0;
  }
  if (typeof bodyData.use !== 'undefined') {
    updates.use = normalizeUseFlag(bodyData.use);
  }
  if (typeof bodyData.refdefaultbudgetsource !== 'undefined'
    || typeof bodyData.refDefaultBudgetSource !== 'undefined') {
    const resolvedBs = await resolveRefDefaultBudgetSource(bodyData);
    if (!resolvedBs.ok) {
      return { status: 'error', message: resolvedBs.message };
    }
    updates.refdefaultbudgetsource = resolvedBs.id;
  }

  if (Object.keys(updates).length === 0) {
    return { status: 'error', message: 'Columns for update not found' };
  }

  const affected = await db(tableName).where('id', id).update(updates);
  if (affected > 0) {
    return { status: 'successfully', message: 'แก้ไขข้อมูลเรียบร้อย' };
  }
  return { status: 'error', message: 'แก้ไขข้อมูลไม่สำเร็จ' };
}

async function remove(id, bodyData = {}) {
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp' };
  }
  if (!id) {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }

  const existing = await db(tableName).where('id', id).first();
  if (!existing) {
    return { status: 'unsuccessful', message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ' };
  }

  const inUse = await db('expensesub').where('refexpensetype', id).first();
  if (inUse) {
    return { status: 'error', message: 'ไม่สามารถลบได้ เนื่องจากมีรายการใช้งานประเภทนี้อยู่' };
  }

  const deleted = await db(tableName).where('id', id).delete();
  if (deleted > 0) {
    return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อย' };
  }
  return { status: 'error', message: 'ลบข้อมูลไม่สำเร็จ' };
}

module.exports = {
  getMultiple,
  create,
  update,
  remove,
};
