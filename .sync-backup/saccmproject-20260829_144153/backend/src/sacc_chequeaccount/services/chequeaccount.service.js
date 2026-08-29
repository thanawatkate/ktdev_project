const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

let cachedTable = null;

async function resolveTable() {
  if (cachedTable) return cachedTable;
  try {
    if (await db.schema.hasTable('chequeaccount')) {
      cachedTable = 'chequeaccount';
      return cachedTable;
    }
  } catch (_) {}
  try {
    if (await db.schema.hasTable('saccchequeaccount')) {
      cachedTable = 'saccchequeaccount';
      return cachedTable;
    }
  } catch (_) {}
  cachedTable = 'chequeaccount';
  return cachedTable;
}

function accountNameColumn(tableName) {
  return tableName === 'chequeaccount' ? 'chequemame' : 'chequemame';
}

function bankFkColumn(tableName) {
  return tableName === 'chequeaccount' ? 'refbank' : 'refsaccbank';
}

function normalizeRow(row, tableName) {
  if (!row) return row;
  const nameCol = accountNameColumn(tableName);
  const bankCol = bankFkColumn(tableName);
  const name = row[nameCol] ?? row.chequename ?? '';
  const bank = row[bankCol] ?? row.refbank ?? row.refsaccbank ?? null;
  return {
    ...row,
    chequemame: name,
    chequename: name,
    refbank: bank,
  };
}

async function getMultiple(page = 1) {
  const tableName = await resolveTable();
  const offset = helper.getOffset(page, config.listPerPage);
  const raw = await db(tableName)
    .select('*')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);
  const rows = raw.map((r) => normalizeRow(r, tableName));
  return { data: helper.emptyOrRows(rows), meta: { page } };
}

async function create(bodyData) {
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };

  const chequeno = (bodyData.chequeno || '').toString().trim();
  const name = (bodyData.chequemame || bodyData.chequename || '').toString().trim();
  const refbank = bodyData.refbank ?? bodyData.refsaccbank;
  if (!chequeno) return { status: 'error', message: 'chequeno require' };
  if (!name) return { status: 'error', message: 'chequename require' };
  if (!refbank) return { status: 'error', message: 'refbank require' };

  const tableName = await resolveTable();
  const nameCol = accountNameColumn(tableName);
  const bankCol = bankFkColumn(tableName);
  const row = {
    chequeno,
    [nameCol]: name,
    [bankCol]: refbank,
  };
  if (tableName === 'chequeaccount') {
    row.sort = parseInt(String(bodyData.sort ?? '0'), 10) || 0;
    row.use = (bodyData.use || 'Y').toString().trim() === 'N' ? 'N' : 'Y';
  }

  const inserted = await db(tableName).insert(row);
  return {
    status: inserted[0] ? 'successfully' : 'error',
    message: inserted[0] ? 'บันทึกข้อมูลเรียบร้อยแล้ว' : 'บันทึกข้อมูลไม่สำเร็จ',
    lastId: inserted[0] || null,
  };
}

async function update(id, bodyData) {
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };

  const tableName = await resolveTable();
  const existing = await db(tableName).where('id', id).first();
  if (!existing) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตรวจสอบใหม่อีกครั้ง...' };
  }

  const nameCol = accountNameColumn(tableName);
  const bankCol = bankFkColumn(tableName);
  const updateFields = {};
  if (typeof bodyData.chequeno !== 'undefined') updateFields.chequeno = bodyData.chequeno || null;
  if (typeof bodyData.chequemame !== 'undefined' || typeof bodyData.chequename !== 'undefined') {
    updateFields[nameCol] = (bodyData.chequemame || bodyData.chequename || '').toString().trim();
  }
  if (typeof bodyData.refbank !== 'undefined' || typeof bodyData.refsaccbank !== 'undefined') {
    updateFields[bankCol] = bodyData.refbank ?? bodyData.refsaccbank;
  }
  if (typeof bodyData.sort !== 'undefined') {
    updateFields.sort = parseInt(String(bodyData.sort), 10) || 0;
  }
  if (typeof bodyData.use !== 'undefined') {
    updateFields.use = bodyData.use.toString().trim() === 'N' ? 'N' : 'Y';
  }
  if (Object.keys(updateFields).length === 0) {
    return { status: 'error', message: 'ไม่มีข้อมูลสำหรับอัปเดต' };
  }

  await db(tableName).where('id', id).update(updateFields);
  return { status: 'successfully', message: 'อัปเดตข้อมูลเรียบร้อยแล้ว' };
}

async function remove(id, bodyData) {
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };

  const tableName = await resolveTable();
  const result = await db(tableName).where('id', id).delete();
  if (result > 0) return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อย' };
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
