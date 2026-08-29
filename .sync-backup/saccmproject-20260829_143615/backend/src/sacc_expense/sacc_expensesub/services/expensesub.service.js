const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

const tableName = 'expensesub';

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(tableName)
    .select('*')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);
  return { data: helper.emptyOrRows(rows), meta: { page } };
}

function parseOptionalInt(v) {
  if (v === null || typeof v === 'undefined' || v === '') return null;
  const n = parseInt(String(v), 10);
  return Number.isFinite(n) ? n : null;
}

function parseAmount(v) {
  const n = parseFloat(String(v ?? '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : 0;
}

async function create(bodyData) {
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  if (!bodyData.refexpense) return { status: 'error', message: 'refexpense require' };

  const inserted = await db(tableName).insert({
    refexpense: parseOptionalInt(bodyData.refexpense),
    refincometype: parseOptionalInt(bodyData.refincometype),
    refexpensetype: parseOptionalInt(bodyData.refexpensetype),
    refmoneytype: parseOptionalInt(bodyData.refmoneytype),
    amount: parseAmount(bodyData.amount),
    remark: bodyData.remark != null ? String(bodyData.remark) : '',
    pay_category: bodyData.pay_category || null,
  });

  return {
    status: inserted[0] ? 'successfully' : 'error',
    message: inserted[0] ? 'บันทึกข้อมูลสำเร็จ' : 'บันทึกข้อมูลไม่สำเร็จ',
    lastId: inserted[0] || null,
  };
}

async function update(id, bodyData) {
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };

  const existing = await db(tableName).where('id', id).first();
  if (!existing) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }

  const updateFields = {};
  if (typeof bodyData.refexpense !== 'undefined') updateFields.refexpense = parseOptionalInt(bodyData.refexpense);
  if (typeof bodyData.refincometype !== 'undefined') updateFields.refincometype = parseOptionalInt(bodyData.refincometype);
  if (typeof bodyData.refexpensetype !== 'undefined') updateFields.refexpensetype = parseOptionalInt(bodyData.refexpensetype);
  if (typeof bodyData.refmoneytype !== 'undefined') updateFields.refmoneytype = parseOptionalInt(bodyData.refmoneytype);
  if (typeof bodyData.amount !== 'undefined') updateFields.amount = parseAmount(bodyData.amount);
  if (typeof bodyData.remark !== 'undefined') updateFields.remark = bodyData.remark || '';
  if (typeof bodyData.pay_category !== 'undefined') updateFields.pay_category = bodyData.pay_category || null;
  if (Object.keys(updateFields).length === 0) return { status: 'error', message: 'ไม่มีข้อมูลสำหรับอัปเดต' };

  await db(tableName).where('id', id).update(updateFields);
  return { status: 'successfully', message: 'อัปเดตข้อมูลเรียบร้อยแล้ว' };
}

async function remove(id, bodyData) {
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  const result = await db(tableName).where('id', id).delete();
  if (result > 0) return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อย' };
  return { status: 'unsuccessful', message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ' };
}

async function createInExpenseSub(mainID, data) {
  const rows = typeof data === 'string' ? JSON.parse(data) : (data || []);
  for (const row of rows) {
    await db(tableName).insert({
      refexpense: mainID,
      refexpensetype: parseOptionalInt(row.refexpensetype ?? row.refExpenseType),
      refincometype: parseOptionalInt(row.refincometype ?? row.refFundCategory),
      refmoneytype: parseOptionalInt(row.refmoneytype ?? row.refMoneyType),
      amount: parseAmount(row.amount),
      remark: row.remark != null ? String(row.remark) : '',
      pay_category: row.pay_category != null && row.pay_category !== '' ? String(row.pay_category) : null,
    });
  }
  return true;
}

async function updateInExpenseSub(mainID, data) {
  const rows = typeof data === 'string' ? JSON.parse(data) : (data || []);
  await db(tableName).where('refexpense', mainID).delete();
  await createInExpenseSub(mainID, rows);
  return true;
}

module.exports = {
  getMultiple,
  create,
  update,
  remove,
  createInExpenseSub,
  updateInExpenseSub,
};
