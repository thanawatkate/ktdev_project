const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

let cachedPayChequeTable = null;

async function resolvePayChequeTable() {
  if (cachedPayChequeTable) return cachedPayChequeTable;
  try {
    if (await db.schema.hasTable('paycheque')) {
      cachedPayChequeTable = 'paycheque';
      return cachedPayChequeTable;
    }
  } catch (_) {}
  try {
    if (await db.schema.hasTable('saccpaycheque')) {
      cachedPayChequeTable = 'saccpaycheque';
      return cachedPayChequeTable;
    }
  } catch (_) {}
  cachedPayChequeTable = 'paycheque';
  return cachedPayChequeTable;
}

function parseAmount(v) {
  const n = parseFloat(String(v ?? '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : 0;
}

function parsePayRows(payCheque) {
  if (Array.isArray(payCheque)) return payCheque;
  if (typeof payCheque === 'string' && payCheque.trim()) return JSON.parse(payCheque);
  return [];
}

async function getMultiple(page = 1) {
  const tableName = await resolvePayChequeTable();
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(tableName)
    .select('*')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);
  return { data: helper.emptyOrRows(rows), meta: { page } };
}

async function create(token, bodyData) {
  if (!token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(token)) return { status: 'error', message: 'Token exp' };
  const tableName = await resolvePayChequeTable();
  const chequeAmount = parseAmount(bodyData.chequeamount);
  const clearedAt = bodyData.cleared_at ?? bodyData.clearedAt ?? null;
  const inserted = await db(tableName).insert({
    chequeamount: parseFloat(chequeAmount.toFixed(2)),
    refchequeaccount: bodyData.refchequeaccount || null,
    refexpense: bodyData.refexpense || null,
    chequeno: bodyData.chequeno || null,
    remark: bodyData.remark || '',
    cleared_at: clearedAt || null,
  });
  return {
    status: inserted[0] ? 'successfully' : 'error',
    message: inserted[0] ? 'บันทึกข้อมูลเรียบร้อยแล้ว' : 'บันทึกข้อมูลไม่สำเร็จ',
    lastId: inserted[0] || null,
  };
}

async function createPayCheque(token, refexpense, bodyData, trx = db) {
  if (!token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(token)) return { status: 'error', message: 'Token exp' };

  const tableName = await resolvePayChequeTable();
  const payRows = parsePayRows(bodyData?.payCheque);
  let lastId = null;
  for (const row of payRows) {
    const clearedAt = row.cleared_at ?? row.clearedAt ?? null;
    const inserted = await trx(tableName).insert({
      chequeamount: parseFloat(parseAmount(row.chequeamount).toFixed(2)),
      refchequeaccount: row.refchequeaccount || null,
      refexpense,
      chequeno: row.chequeno || null,
      remark: row.remark || '',
      cleared_at: clearedAt || null,
    });
    if (inserted[0]) lastId = inserted[0];
  }
  return { status: 'successfully', message: 'บันทึกข้อมูลเรียบร้อยแล้ว', lastId };
}

async function update(id, bodyData) {
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  const tableName = await resolvePayChequeTable();
  const existing = await db(tableName).where('id', id).first();
  if (!existing) return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };

  const updateFields = {};
  if (typeof bodyData.chequeamount !== 'undefined') {
    updateFields.chequeamount = parseFloat(parseAmount(bodyData.chequeamount).toFixed(2));
  }
  if (typeof bodyData.refchequeaccount !== 'undefined') updateFields.refchequeaccount = bodyData.refchequeaccount || null;
  if (typeof bodyData.refexpense !== 'undefined') updateFields.refexpense = bodyData.refexpense || null;
  if (typeof bodyData.chequeno !== 'undefined') updateFields.chequeno = bodyData.chequeno || null;
  if (typeof bodyData.remark !== 'undefined') updateFields.remark = bodyData.remark || '';
  if (typeof bodyData.cleared_at !== 'undefined' || typeof bodyData.clearedAt !== 'undefined') {
    const raw = bodyData.cleared_at ?? bodyData.clearedAt;
    if (raw === null || raw === '' || raw === false) {
      updateFields.cleared_at = null;
    } else if (raw === true) {
      updateFields.cleared_at = new Date();
    } else {
      const d = new Date(raw);
      updateFields.cleared_at = Number.isNaN(d.getTime()) ? new Date() : d;
    }
  }
  if (Object.keys(updateFields).length === 0) return { status: 'error', message: 'ไม่มีข้อมูลสำหรับอัปเดต' };

  await db(tableName).where('id', id).update(updateFields);
  return { status: 'successfully', message: 'อัปเดตข้อมูลเรียบร้อยแล้ว' };
}

async function remove(id, bodyData) {
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  const tableName = await resolvePayChequeTable();
  const result = await db(tableName).where('id', id).delete();
  if (result > 0) return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อย' };
  return { status: 'unsuccessful', message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ' };
}

module.exports = {
  getMultiple,
  create,
  update,
  remove,
  createPayCheque,
};
