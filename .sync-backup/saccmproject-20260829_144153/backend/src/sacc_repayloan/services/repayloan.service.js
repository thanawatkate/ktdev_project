const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { createInRepayloanSub } = require('../../sacc_repayloansub/controllers/repayloansub.controller');
const tableName = 'repayloan'

function parseSubdata(raw) {
  if (raw == null || raw === '') return [];
  if (Array.isArray(raw)) return raw;
  return JSON.parse(raw);
}

function parseAmount(value) {
  const n = parseFloat(String(value ?? '0').replace(/,/g, ''));
  return Number.isFinite(n) ? n : 0;
}

function sumSubdataAmount(rows) {
  return rows.reduce((sum, row) => sum + parseAmount(row.amount), 0);
}

async function resolveLoanId(bodyData) {
  const raw = bodyData.refloan ?? bodyData.refLoan;
  const ref = String(raw ?? '').trim();
  const docno = String(bodyData.refloan_docno ?? bodyData.refLoanDocno ?? '').trim();
  if (!ref && !docno) return null;
  if (/^\d+$/.test(ref)) {
    const byId = await db('loan').where('id', Number(ref)).first();
    if (byId) return byId.id;
  }
  const byDocno = await db('loan')
    .where((qb) => {
      if (ref) qb.orWhere('docno', ref);
      if (docno) qb.orWhere('docno', docno);
    })
    .first();
  return byDocno?.id ?? null;
}

async function outstandingForLoan(refloan, { excludeRepayId = null } = {}) {
  const loan = await db('loan')
    .select('id', 'amount', 'opening_outstanding')
    .where('id', refloan)
    .first();
  if (!loan) return null;
  const repayQ = db('repayloan').where('refloan', refloan);
  if (excludeRepayId) repayQ.whereNot('id', excludeRepayId);
  const repaidRow = await repayQ.sum({ repaid: 'amount' }).first();
  const principal = parseAmount(loan.amount);
  const opening = parseAmount(loan.opening_outstanding);
  const repaid = parseAmount(repaidRow?.repaid);
  return principal + opening - repaid;
}

async function buildRepaySubdataFromLoan(refloan, amount, { excludeRepayId = null } = {}) {
  const loanSubs = await db('loansub')
    .select('refincometype', 'amount')
    .where('refloan', refloan)
    .orderBy('id', 'asc');
  if (loanSubs.length === 0) return [];

  const repaidRows = await db('repayloan as r')
    .join('repayloansub as rs', 'r.id', 'rs.refrepayloan')
    .select('rs.refincometype')
    .sum({ amount: 'rs.amount' })
    .where('r.refloan', refloan)
    .modify((qb) => {
      if (excludeRepayId) qb.whereNot('r.id', excludeRepayId);
    })
    .groupBy('rs.refincometype');
  const repaidByType = new Map(
    repaidRows.map((row) => [String(row.refincometype ?? ''), parseAmount(row.amount)]),
  );

  let remainingToAllocate = parseAmount(amount);
  const out = [];
  for (const row of loanSubs) {
    if (remainingToAllocate <= 0) break;
    const type = row.refincometype || null;
    const key = String(type ?? '');
    const available = Math.max(0, parseAmount(row.amount) - (repaidByType.get(key) || 0));
    if (available <= 0) continue;
    const allocated = Math.min(available, remainingToAllocate);
    if (allocated > 0) {
      out.push({
        amount: Number(allocated.toFixed(2)),
        remark: null,
        refincometype: type,
      });
      remainingToAllocate -= allocated;
    }
  }
  return out;
}

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(tableName)
    .select('*')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);
  const data = helper.emptyOrRows(rows);
  const meta = { page };
  return {
    data,
    meta
  }
}

async function findRepayByIdOrDocno(id, bodyData = {}) {
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

async function create(bodyData) {
  if (bodyData.token === "" || typeof bodyData.token === "undefined") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res

  } else if (bodyData.docno === "" || typeof bodyData.docno === "undefined") {
    let res = {
      status: 'error',
      message: 'docno require '
    };
    return res
  } else if (bodyData.duedate === "" || typeof bodyData.duedate === "undefined") {
    let res = {
      status: 'error',
      message: 'duedate require '
    };
    return res
  }
  else if ((bodyData.refloan === "" || typeof bodyData.refloan === "undefined") &&
    (bodyData.refloan_docno === "" || typeof bodyData.refloan_docno === "undefined")) {
    let res = {
      status: 'error',
      message: 'refloan require '
    };
    return res
  }
  if (checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const refloan = await resolveLoanId(bodyData);
  if (!refloan) {
    return { status: 'error', message: 'refloan ไม่พบสัญญายืมเงิน' };
  }

  let subdata = [];
  try {
    subdata = parseSubdata(bodyData.subdata);
  } catch (_) {
    return { status: 'error', message: 'subdata ไม่ใช่ JSON ที่ถูกต้อง' };
  }
  if (!Array.isArray(subdata)) {
    return { status: 'error', message: 'subdata ไม่ใช่ JSON ที่ถูกต้อง' };
  }

  const amount = subdata.length > 0 ? sumSubdataAmount(subdata) : parseAmount(bodyData.amount);
  if (amount <= 0) {
    return { status: 'error', message: 'amount require ' };
  }
  const existingDoc = await db(tableName).where('docno', String(bodyData.docno).trim()).first();
  if (existingDoc) {
    const updated = await update(existingDoc.id, { ...bodyData, refloan });
    if (updated.status === 'successfully') {
      return { ...updated, lastId: existingDoc.id };
    }
    return updated;
  }
  const outstanding = await outstandingForLoan(refloan);
  if (outstanding == null) {
    return { status: 'error', message: 'refloan ไม่พบสัญญายืมเงิน' };
  }
  if (amount > outstanding + 0.0001) {
    return {
      status: 'error',
      message: `ยอดคืนเงินยืมเกินยอดคงค้าง (${outstanding.toFixed(2)} บาท)`,
    };
  }
  if (subdata.length === 0) {
    subdata = await buildRepaySubdataFromLoan(refloan, amount);
  }
  try {
    let insertedId;
    await db.transaction(async (trx) => {
      const result = await trx(tableName).insert({
        docno: String(bodyData.docno).trim(),
        duedate: new Date(bodyData.duedate),
        amount: Number(amount.toFixed(2)),
        remark: bodyData.remark || null,
        refloan,
      });
      insertedId = result[0];
      if (subdata.length > 0) {
        await trx.batchInsert(
          'repayloansub',
          subdata.map((row) => ({
            amount: parseAmount(row.amount),
            remark: row.remark || null,
            refrepayloan: insertedId,
            refincometype: row.refincometype || row.refIncomeType || null,
          })),
          100,
        );
      }
    });
    if (insertedId > 0) {
      return {
        status: 'successfully',
        message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
        lastId: insertedId
      };
    }
    return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
  } catch (e) {
    return { status: 'error', message: e.message || 'บันทึกข้อมูลไม่สำเร็จ' };
  }
}
async function update(id, bodyData) {
  if (bodyData.token === "" || typeof bodyData.token === "undefined") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res
  }
  if (id === "" || typeof id === 'undefined') {
    let res = {
      status: 'error',
      message: 'id ข้อมูลไม่ควรเป็นค่าว่าง'
    };
    return (res)
  }

  if (checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const existing = await findRepayByIdOrDocno(id, bodyData);
  if (!existing) {
    let res = {
      status: 'error',
      message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...'
    };
    return (res)
  }
  id = existing.id;

  const fields = {};
  if (bodyData.docno !== undefined && bodyData.docno !== '') fields.docno = bodyData.docno;
  if (bodyData.duedate !== undefined && bodyData.duedate !== '') {
    fields.duedate = new Date(bodyData.duedate);
  }
  if (bodyData.amount !== undefined && bodyData.amount !== '') {
    fields.amount = parseAmount(bodyData.amount);
  }
  if (bodyData.remark !== undefined) fields.remark = bodyData.remark || null;
  if ((bodyData.refloan !== undefined && bodyData.refloan !== '') ||
    (bodyData.refloan_docno !== undefined && bodyData.refloan_docno !== '')) {
    const resolved = await resolveLoanId(bodyData);
    if (!resolved) return { status: 'error', message: 'refloan ไม่พบสัญญายืมเงิน' };
    fields.refloan = resolved;
  }

  if (bodyData.subdata !== undefined && bodyData.subdata !== '') {
    let subdata;
    try {
      subdata = parseSubdata(bodyData.subdata);
    } catch (_) {
      return { status: 'error', message: 'subdata ไม่ใช่ JSON ที่ถูกต้อง' };
    }
    if (!Array.isArray(subdata) || subdata.length === 0) {
      return { status: 'error', message: 'subdata require ' };
    }
    fields.amount = Number(sumSubdataAmount(subdata).toFixed(2));
    const refloan = fields.refloan || existing.refloan;
    const outstanding = await outstandingForLoan(refloan, { excludeRepayId: id });
    if (outstanding == null) {
      return { status: 'error', message: 'refloan ไม่พบสัญญายืมเงิน' };
    }
    if (fields.amount > outstanding + 0.0001) {
      return {
        status: 'error',
        message: `ยอดคืนเงินยืมเกินยอดคงค้าง (${outstanding.toFixed(2)} บาท)`,
      };
    }
    fields.updated = db.fn.now();
    await db.transaction(async (trx) => {
      await trx(tableName).where('id', id).update(fields);
      await trx('repayloansub').where('refrepayloan', id).del();
      await trx.batchInsert(
        'repayloansub',
        subdata.map((row) => ({
          amount: parseAmount(row.amount),
          remark: row.remark || null,
          refrepayloan: id,
          refincometype: row.refincometype || row.refIncomeType || null,
        })),
        100,
      );
    });
    return { status: 'successfully', message: 1 };
  }

  if (Object.keys(fields).length < 1) {
    return { status: 'error', message: 'Columns for update not found' };
  }
  fields.updated = db.fn.now();
  if (fields.amount !== undefined || fields.refloan !== undefined) {
    const refloan = fields.refloan || existing.refloan;
    const amount = fields.amount !== undefined ? fields.amount : parseAmount(existing.amount);
    const outstanding = await outstandingForLoan(refloan, { excludeRepayId: id });
    if (outstanding == null) {
      return { status: 'error', message: 'refloan ไม่พบสัญญายืมเงิน' };
    }
    if (amount > outstanding + 0.0001) {
      return {
        status: 'error',
        message: `ยอดคืนเงินยืมเกินยอดคงค้าง (${outstanding.toFixed(2)} บาท)`,
      };
    }
    const autoSubdata = await buildRepaySubdataFromLoan(refloan, amount, { excludeRepayId: id });
    if (autoSubdata.length > 0) {
      await db.transaction(async (trx) => {
        await trx(tableName).where('id', id).update({ ...fields, amount });
        await trx('repayloansub').where('refrepayloan', id).del();
        await trx.batchInsert(
          'repayloansub',
          autoSubdata.map((row) => ({
            amount: parseAmount(row.amount),
            remark: row.remark || null,
            refrepayloan: id,
            refincometype: row.refincometype || row.refIncomeType || null,
          })),
          100,
        );
      });
      return { status: 'successfully', message: 1 };
    }
  }
  const result = await db(tableName).where('id', id).update(fields);
  return { status: 'successfully', message: result };
}

async function remove(id, bodyData) {
  if (id === "" || typeof id === 'undefined') {
    let res = {
      status: 'error',
      message: 'id ข้อมูลไม่ควรเป็นค่าว่าง'
    };
    return (res)
  }
  if (!bodyData?.token) {
    return { status: 'error', message: 'Token not found ' };
  }
  if (checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }
  const existing = await findRepayByIdOrDocno(id, bodyData);
  if (!existing) {
    return {
      status: 'unsuccessful',
      message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ',
    };
  }
  let result = await db(tableName).where('id', '=', existing.id).delete()

  if (result > 0) {
    let res = {
      status: 'successfully',
      message: 'ลบข้อมูลเรียบร้อย'
    };
    return (res)
  }
  let res = {
    status: 'unsuccessful',
    message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ'
  };
  return (res)
}

module.exports = {
  getMultiple,
  create,
  update,
  remove
}
