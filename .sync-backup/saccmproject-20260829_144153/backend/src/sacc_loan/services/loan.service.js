const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { createInLoanSub } = require('../../sacc_loansub/controllers/loansub.controller');

const tableName = 'loan';

function parseOpeningOutstanding(bodyData) {
  const v = bodyData.opening_outstanding ?? bodyData.openingOutstanding;
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : 0;
}

async function hasOutstandingLoan(refmember, { excludeLoanId = null } = {}) {
  if (!refmember) return null;
  const loans = await db('loan')
    .select('id', 'docno', 'amount', 'opening_outstanding', 'duedate')
    .where('refmember', refmember)
    .orderBy('created', 'desc');
  for (const loan of loans) {
    if (excludeLoanId && String(loan.id) === String(excludeLoanId)) continue;
    const repaidRow = await db('repayloan')
      .where('refloan', loan.id)
      .sum({ repaid: 'amount' })
      .first();
    const principal = parseFloat(loan.amount) || 0;
    const opening = parseFloat(loan.opening_outstanding) || 0;
    const repaid = parseFloat(repaidRow?.repaid) || 0;
    const outstanding = principal + opening - repaid;
    if (outstanding > 0.0001) {
      return {
        docno: loan.docno,
        duedate: loan.duedate,
        outstanding: parseFloat(outstanding.toFixed(2)),
      };
    }
  }
  return null;
}

async function resolveMemberId(bodyData) {
  const raw = bodyData.refmember ?? bodyData.refMember;
  let id = parseInt(raw, 10);
  if (Number.isFinite(id) && id > 0) return id;
  const name = String(raw ?? '').trim();
  if (!name) return null;
  const row =
    (await db('member')
      .whereRaw("TRIM(CONCAT(COALESCE(name,''),' ',COALESCE(lastname,''))) = ?", [name])
      .first()) || (await db('member').where('name', name).first());
  return row?.id ?? null;
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

async function findLoanByIdOrDocno(id, bodyData = {}) {
  const raw = String(id ?? '').trim();
  if (!raw) return null;
  if (/^\d+$/.test(raw)) {
    const byId = await db(tableName).where('id', Number(raw)).first();
    if (byId) return byId;
  }
  const docno = String(bodyData.docno ?? '').trim();
  return db(tableName)
    .where((qb) => {
      qb.orWhere('docno', raw);
      if (docno) qb.orWhere('docno', docno);
    })
    .first();
}

/** สร้างใบยืมแบบไม่มีรายการย่อย (รองรับ sync จากแอป) */
async function createLoanSimple(bodyData) {
  const openingOut = parseOpeningOutstanding(bodyData);
  const amt = parseFloat(bodyData.amount) || 0;
  if (amt <= 0 && openingOut <= 0) {
    return { status: 'error', message: 'ต้องระบุ amount หรือ opening_outstanding อย่างน้อยหนึ่งค่า' };
  }
  if (!bodyData.docno) {
    return { status: 'error', message: 'docno require ' };
  }

  const refmember = await resolveMemberId(bodyData);
  if (!refmember) {
    return { status: 'error', message: 'refmember ไม่พบสมาชิก (ใช้รหัสสมาชิกหรือชื่อที่ตรงกับข้อมูลสมาชิก)' };
  }

  const loandate = bodyData.loandate ? new Date(bodyData.loandate) : new Date();
  const duedate = bodyData.duedate ? new Date(bodyData.duedate) : loandate;
  if (duedate < loandate) {
    return { status: 'error', message: 'duedate ต้องไม่น้อยกว่า loandate' };
  }
  const remark = bodyData.remark != null ? String(bodyData.remark) : '';
  const existingDoc = await db(tableName).where('docno', String(bodyData.docno).trim()).first();
  if (existingDoc) {
    const updated = await update(existingDoc.id, bodyData);
    if (updated.status === 'successfully') {
      return { ...updated, lastId: existingDoc.id };
    }
    return updated;
  }
  const outstanding = await hasOutstandingLoan(refmember);
  if (outstanding) {
    return {
      status: 'error',
      message: `ผู้ยืมยังมีหนี้ค้างจากใบยืม ${outstanding.docno} (คงเหลือ ${outstanding.outstanding} บาท)`,
    };
  }

  try {
    const [insertId] = await db(tableName).insert({
      docno: String(bodyData.docno).trim(),
      loandate,
      duedate,
      amount: amt,
      opening_outstanding: openingOut,
      remark,
      refmember,
      created: db.fn.now(),
      updated: db.fn.now(),
    });
    if (insertId > 0) {
      return {
        status: 'successfully',
        message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
        lastId: insertId,
      };
    }
    return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
  } catch (e) {
    return { status: 'error', message: e.message || 'บันทึกข้อมูลไม่สำเร็จ' };
  }
}

function hasSubdata(bodyData) {
  const s = bodyData.subdata;
  if (s == null || s === '') return false;
  try {
    const arr = typeof s === 'string' ? JSON.parse(s) : s;
    return Array.isArray(arr) && arr.length > 0;
  } catch (_) {
    return false;
  }
}

function parseSubdata(raw) {
  if (raw == null || raw === '') return null;
  if (Array.isArray(raw)) return raw;
  return JSON.parse(raw);
}

function sumLoanSubdataAmount(rows) {
  return rows.reduce((sum, row) => sum + (parseFloat(row.amount) || 0), 0);
}

async function repaidForLoan(loanId) {
  const row = await db('repayloan')
    .where('refloan', loanId)
    .sum({ repaid: 'amount' })
    .first();
  return parseFloat(row?.repaid) || 0;
}

async function create(bodyData) {
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found ' };
  }
  if (checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }
  if (!bodyData.docno) {
    return { status: 'error', message: 'docno require ' };
  }

  if (!hasSubdata(bodyData)) {
    return createLoanSimple(bodyData);
  }

  if (!bodyData.loandate) {
    return { status: 'error', message: 'loandate require ' };
  }
  if (!bodyData.duedate) {
    return { status: 'error', message: 'duedate require ' };
  }
  if (bodyData.refmember === '' || bodyData.refmember == null) {
    return { status: 'error', message: 'refmember require ' };
  }

  const refmember = await resolveMemberId(bodyData);
  if (!refmember) {
    return { status: 'error', message: 'refmember ไม่พบสมาชิก' };
  }

  const remark = bodyData.remark != null ? String(bodyData.remark) : '';
  const openingOut = parseOpeningOutstanding(bodyData);
  const loandate = new Date(bodyData.loandate);
  const duedate = new Date(bodyData.duedate);
  if (duedate < loandate) {
    return { status: 'error', message: 'duedate ต้องไม่น้อยกว่า loandate' };
  }
  const existingDoc = await db(tableName).where('docno', String(bodyData.docno).trim()).first();
  if (existingDoc) {
    const updated = await update(existingDoc.id, bodyData);
    if (updated.status === 'successfully') {
      return { ...updated, lastId: existingDoc.id };
    }
    return updated;
  }
  const outstanding = await hasOutstandingLoan(refmember);
  if (outstanding) {
    return {
      status: 'error',
      message: `ผู้ยืมยังมีหนี้ค้างจากใบยืม ${outstanding.docno} (คงเหลือ ${outstanding.outstanding} บาท)`,
    };
  }

  let subdata;
  try {
    subdata = JSON.parse(bodyData.subdata);
  } catch (_) {
    return { status: 'error', message: 'subdata ไม่ใช่ JSON ที่ถูกต้อง' };
  }

  let amount = 0;
  for (let index = 0; index < subdata.length; index++) {
    for (const obj in subdata[index]) {
      if (obj === 'amount') {
        amount += parseFloat(subdata[index][obj]) || 0;
      }
    }
  }

  try {
    const [insertId] = await db(tableName).insert({
      docno: String(bodyData.docno).trim(),
      loandate,
      duedate,
      amount,
      opening_outstanding: openingOut,
      remark,
      refmember,
      created: db.fn.now(),
      updated: db.fn.now(),
    });

    if (insertId > 0) {
      await createInLoanSub(insertId, bodyData.subdata);
      return {
        status: 'successfully',
        message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
        lastId: insertId,
      };
    }
    return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
  } catch (e) {
    return { status: 'error', message: e.message || 'บันทึกข้อมูลไม่สำเร็จ' };
  }
}

async function update(id, bodyData) {
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found ' };
  }
  if (checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }
  if (id === '' || id == null) {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }

  const existing = await findLoanByIdOrDocno(id, bodyData);
  if (!existing) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }
  id = existing.id;

  const fields = {};
  if (bodyData.docno !== undefined && bodyData.docno !== '') {
    fields.docno = bodyData.docno;
  }
  if (bodyData.loandate !== undefined && bodyData.loandate !== '') {
    fields.loandate = new Date(bodyData.loandate);
  }
  if (bodyData.duedate !== undefined && bodyData.duedate !== '') {
    fields.duedate = new Date(bodyData.duedate);
  }
  if (bodyData.amount !== undefined && bodyData.amount !== '') {
    fields.amount = parseFloat(bodyData.amount) || 0;
  }
  let subdata = null;
  if (bodyData.subdata !== undefined && bodyData.subdata !== '') {
    try {
      subdata = parseSubdata(bodyData.subdata);
    } catch (_) {
      return { status: 'error', message: 'subdata ไม่ใช่ JSON ที่ถูกต้อง' };
    }
    if (!Array.isArray(subdata)) {
      return { status: 'error', message: 'subdata ไม่ใช่ JSON ที่ถูกต้อง' };
    }
    fields.amount = sumLoanSubdataAmount(subdata);
  }
  if (bodyData.opening_outstanding !== undefined || bodyData.openingOutstanding !== undefined) {
    fields.opening_outstanding = parseOpeningOutstanding(bodyData);
  }
  if (bodyData.remark !== undefined) {
    fields.remark = bodyData.remark;
  }
  if (bodyData.refmember !== undefined && bodyData.refmember !== '') {
    const mid = await resolveMemberId(bodyData);
    if (mid) fields.refmember = mid;
  }
  const targetRefMember = fields.refmember || existing.refmember;
  const pendingOutstanding = await hasOutstandingLoan(targetRefMember, {
    excludeLoanId: id,
  });
  if (pendingOutstanding) {
    return {
      status: 'error',
      message: `ผู้ยืมยังมีหนี้ค้างจากใบยืม ${pendingOutstanding.docno} (คงเหลือ ${pendingOutstanding.outstanding} บาท)`,
    };
  }
  const nextAmount = fields.amount !== undefined ? fields.amount : (parseFloat(existing.amount) || 0);
  const nextOpening = fields.opening_outstanding !== undefined
    ? fields.opening_outstanding
    : (parseFloat(existing.opening_outstanding) || 0);
  const repaid = await repaidForLoan(id);
  if (nextAmount + nextOpening + 0.0001 < repaid) {
    return {
      status: 'error',
      message: `ยอดเงินยืมหลังแก้ไขต้องไม่น้อยกว่ายอดคืนแล้ว (${repaid.toFixed(2)} บาท)`,
    };
  }
  const nextLoanDate = fields.loandate || existing.loandate;
  const nextDueDate = fields.duedate || existing.duedate;
  if (nextLoanDate && nextDueDate && new Date(nextDueDate) < new Date(nextLoanDate)) {
    return { status: 'error', message: 'duedate ต้องไม่น้อยกว่า loandate' };
  }

  if (Object.keys(fields).length < 1) {
    return { status: 'error', message: 'ไม่มีฟิลด์สำหรับอัปเดต' };
  }

  fields.updated = db.fn.now();
  if (subdata != null) {
    await db.transaction(async (trx) => {
      await trx(tableName).where('id', id).update(fields);
      await trx('loansub').where('refloan', id).del();
      if (subdata.length > 0) {
        await trx.batchInsert(
          'loansub',
          subdata.map((row) => ({
            refloan: id,
            refincometype: row.refincometype || row.refIncomeType || null,
            amount: parseFloat(row.amount) || 0,
            remark: row.remark || null,
          })),
          100,
        );
      }
    });
    return { status: 'successfully', message: 1 };
  }
  const result = await db(tableName).where('id', id).update(fields);
  return { status: 'successfully', message: result };
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

  const existing = await findLoanByIdOrDocno(id, bodyData);
  if (!existing) {
    return {
      status: 'unsuccessful',
      message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ',
    };
  }
  const result = await db(tableName).where('id', existing.id).delete();
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
