const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

const tableName = 'bankaccount';

async function resolveRefBankId(bodyData) {
  const raw = bodyData.refbank ?? bodyData.refsaccbank ?? bodyData.refBank;
  const n = parseInt(raw, 10);
  if (Number.isFinite(n) && n > 0) return n;
  const name = String(raw ?? '').trim();
  if (!name) return null;
  const row = await db('bank').where('name', name).first();
  return row?.id ?? null;
}

function parseOpeningBalance(bodyData) {
  const v =
    bodyData.opening_balance ?? bodyData.openingBalance ?? bodyData.opening_balance_baht;
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : 0;
}

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(tableName)
    .select('*')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);
  return { data: rows, meta: { page } };
}

async function create(bodyData) {
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found ' };
  }
  if (checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }
  if (bodyData.accountnumber === '' || bodyData.accountnumber == null) {
    return { status: 'error', message: 'accountnumber  require ' };
  }
  if (bodyData.accountname === '' || bodyData.accountname == null) {
    return { status: 'error', message: 'accountname require ' };
  }

  const refbank = await resolveRefBankId(bodyData);
  if (!refbank) {
    return { status: 'error', message: 'refbank / refsaccbank require (รหัสธนาคารหรือชื่อธนาคารที่มีในระบบ)' };
  }

  const opening = parseOpeningBalance(bodyData);

  try {
    const [insertId] = await db(tableName).insert({
      accountnumber: String(bodyData.accountnumber).trim(),
      accountname: String(bodyData.accountname).trim(),
      refbank,
      opening_balance: opening,
      sort: parseInt(bodyData.sort, 10) || 0,
    });
    if (insertId > 0) {
      return {
        status: 'successfully',
        message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
        lastid: insertId,
      };
    }
    return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
  } catch (e) {
    return { status: 'error', message: e.message || 'บันทึกข้อมูลไม่สำเร็จ' };
  }
}

async function update(id, bodyData) {
  if (id === '' || id == null) {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found ' };
  }
  if (checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const existing = await db(tableName).where('id', id).first();
  if (!existing) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }

  const fields = {};
  if (bodyData.accountname !== undefined && bodyData.accountname !== '') {
    fields.accountname = bodyData.accountname;
  }
  if (bodyData.accountnumber !== undefined && bodyData.accountnumber !== '') {
    fields.accountnumber = bodyData.accountnumber;
  }
  if (
    bodyData.refbank !== undefined ||
    bodyData.refsaccbank !== undefined ||
    bodyData.refBank !== undefined
  ) {
    const refbank = await resolveRefBankId(bodyData);
    if (refbank) fields.refbank = refbank;
  }
  if (bodyData.opening_balance !== undefined || bodyData.openingBalance !== undefined) {
    fields.opening_balance = parseOpeningBalance(bodyData);
  }
  if (bodyData.sort !== undefined && bodyData.sort !== '') {
    fields.sort = parseInt(bodyData.sort, 10);
  }

  if (Object.keys(fields).length < 1) {
    return { status: 'error', message: 'Columns for update  not fond' };
  }

  await db(tableName).where('id', id).update(fields);
  return { status: 'successfully', message: fields };
}

async function remove(id, bodyData) {
  if (id === '' || id == null) {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found ' };
  }
  if (checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const result = await db(tableName).where('id', id).delete();
  if (result > 0) {
    return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อย' };
  }
  return {
    status: 'unsuccessful',
    message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ',
  };
}

module.exports = {
  getMultiple,
  create,
  update,
  remove,
};
