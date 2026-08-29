const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { createInExpenseSub } = require('../../sacc_expensesub/controllers/expensesub.controller');
const { createInPayCheque } = require('../../sacc_paycheque/controllers/paycheque.controller');
const { assertExpenseSubRowsForReporting } = require('../../utils/ledger_subline_validate');
const { assertCashKeepingOnPost } = require('../../utils/cash_keeping_validate');

const tableName = 'expense';
let cachedPayChequeTable = null;
let cachedExpenseSubTable = null;
const IMMUTABLE_AFTER_POSTED = new Set([
  'docno',
  'docdate',
  'amount',
  'chequeamount',
  'bankamount',
  'detail',
  'remark',
  'refmember',
  'refbudgetsource',
  'refexpensereq',
  'refparty',
  'money_domain',
  'refbankaccount',
]);

function parsePositiveInt(v) {
  const n = parseInt(String(v ?? '').trim(), 10);
  return Number.isInteger(n) && n > 0 ? n : null;
}

function parseMoneyDomain(raw) {
  const v = (raw || '').toString().trim().toLowerCase();
  if (v === 'budget' || v === 'off_budget' || v === 'treasury_income') return v;
  return null;
}

function parseDocStatus(raw) {
  const v = (raw || '').toString().trim().toLowerCase();
  if (v === 'draft' || v === 'approved' || v === 'posted') return v;
  return null;
}

function parseJsonArray(input) {
  if (Array.isArray(input)) return input;
  if (typeof input === 'string') {
    const t = input.trim();
    if (!t) return [];
    const parsed = JSON.parse(t);
    return Array.isArray(parsed) ? parsed : [];
  }
  return [];
}

function parseAmount(v) {
  const n = parseFloat(String(v ?? '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : 0;
}

function parseOptionalBankAccountId(bodyData) {
  const raw = bodyData.refbankaccount ?? bodyData.refBankAccount ?? bodyData.ref_bank_account;
  const n = parseInt(String(raw ?? '').trim(), 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function parseOptionalExpenseReqId(bodyData) {
  const raw = bodyData.refexpensereq ?? bodyData.refExpenseReq ?? bodyData.ref_expense_req;
  const n = parseInt(String(raw ?? '').trim(), 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function parseExpenseDocDate(bodyData) {
  const raw = bodyData.docdate ?? bodyData.docDate;
  if (raw === undefined || raw === null || raw === '') return new Date();
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? new Date() : d;
}

function validateStatusTransition(currentStatus, nextStatus) {
  if (!nextStatus || currentStatus === nextStatus) return true;
  const allowed = {
    draft: new Set(['approved', 'posted']),
    approved: new Set(['posted']),
    posted: new Set(['approved']),
  };
  const rules = allowed[currentStatus] || new Set([]);
  return rules.has(nextStatus);
}

async function resolvePayChequeTableName() {
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

async function resolveExpenseSubTableName() {
  if (cachedExpenseSubTable) return cachedExpenseSubTable;
  try {
    if (await db.schema.hasTable('expensesub')) {
      cachedExpenseSubTable = 'expensesub';
      return cachedExpenseSubTable;
    }
  } catch (_) {}
  try {
    if (await db.schema.hasTable('expense_sub')) {
      cachedExpenseSubTable = 'expense_sub';
      return cachedExpenseSubTable;
    }
  } catch (_) {}
  cachedExpenseSubTable = 'expensesub';
  return cachedExpenseSubTable;
}

async function resolvePartyId(bodyData) {
  const refParty = Number(bodyData.refparty);
  if (Number.isFinite(refParty) && refParty > 0) {
    const found = await db('party').where('id', refParty).first();
    if (found) return found.id;
  }

  const partyName = (bodyData.partyname || '').toString().trim();
  if (!partyName) return null;

  const existing = await db('party')
    .whereRaw('LOWER(name) = LOWER(?)', [partyName])
    .andWhereIn('role', ['receiver', 'both'])
    .first();
  if (existing) return existing.id;

  const inserted = await db('party').insert({
    name: partyName,
    role: 'receiver',
    isactive: true,
  });

  return inserted[0] || null;
}

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(`${tableName} as e`)
    .leftJoin('party as p', 'e.refparty', 'p.id')
    .select('e.*', 'p.name as party_name')
    .orderBy('e.created', 'desc')
    .limit(config.listPerPage)
    .offset(offset);
  const data = helper.emptyOrRows(rows);
  const meta = { page };
  return { data, meta };
}

async function create(bodyData) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  if (!bodyData.docno) return { status: 'error', message: 'docno require' };
  if (typeof bodyData.subdata === 'undefined' || bodyData.subdata === '') {
    return { status: 'error', message: 'subdata require' };
  }

  const subdata = parseJsonArray(bodyData.subdata);
  const payCheque = parseJsonArray(bodyData.payCheque);
  const amount = subdata.reduce((sum, row) => sum + parseAmount(row?.amount), 0);
  const chequeamount = payCheque.reduce((sum, row) => sum + parseAmount(row?.chequeamount), 0);
  const bankamount = parseAmount(bodyData.bankamount);
  const refparty = await resolvePartyId(bodyData);
  const refBudgetSource = parsePositiveInt(bodyData.refbudgetsource ?? bodyData.refBudgetSource);
  if (!refBudgetSource) {
    return { status: 'error', message: 'refbudgetsource require — ระบุแหล่งเงินที่หัวเอกสาร' };
  }
  const bsOk = await db('budgetsource').where('id', refBudgetSource).first('id');
  if (!bsOk) {
    return { status: 'error', message: 'ไม่พบแหล่งเงินที่ระบุ' };
  }
  const refExpenseReq = parseOptionalExpenseReqId(bodyData);
  if (refExpenseReq) {
    const req = await db('expensereq').where('id', refExpenseReq).first('id', 'approval_status');
    if (!req) {
      return { status: 'error', message: 'ไม่พบใบขอเบิกที่อ้างอิง' };
    }
    if (req.approval_status !== 'approved') {
      return { status: 'error', message: 'ใบขอเบิกที่อ้างอิงยังไม่อนุมัติ' };
    }
    const used = await db(tableName)
      .where('refexpensereq', refExpenseReq)
      .whereNotIn('doc_status', ['draft'])
      .first('id');
    if (used) {
      return { status: 'error', message: 'ใบขอเบิกนี้ถูกนำไปบันทึกเบิกจริงแล้ว' };
    }
  }
  const moneyDomain = parseMoneyDomain(bodyData.money_domain || bodyData.moneyDomain);
  const expenseHeaderCtx = {
    refbankaccount: bodyData.refbankaccount ?? bodyData.refBankAccount,
    refbudgetsource: refBudgetSource,
  };
  try {
    await assertExpenseSubRowsForReporting(subdata, moneyDomain, expenseHeaderCtx);
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }
  const docStatus = parseDocStatus(bodyData.doc_status || bodyData.docStatus) || 'draft';
  const docdate = parseExpenseDocDate(bodyData);
  // ค่าเริ่มบัญชีจาก incometype (ผ่าน expensesub.refincometype); ค่านี้ = override ต่อใบจ่าย
  const refbankaccount = parseOptionalBankAccountId(bodyData);

  try {
    await assertCashKeepingOnPost({
      docdate,
      subdata,
      budgetSourceId: refBudgetSource,
      docStatus,
      transactionType: 'expense',
    });
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }

  const hasExpenseRecorded = refExpenseReq
    ? await db.schema.hasColumn('expensereq', 'expense_recorded')
    : false;

  return db.transaction(async (trx) => {
    const inserted = await trx(tableName).insert({
      docno: bodyData.docno,
      docdate,
      amount: parseFloat(amount.toFixed(2)),
      chequeamount: parseFloat(chequeamount.toFixed(2)),
      bankamount: parseFloat(bankamount.toFixed(2)),
      detail: bodyData.detail || '',
      remark: bodyData.remark || '',
      refmember: bodyData.refmember || null,
      refbudgetsource: refBudgetSource,
      refexpensereq: refExpenseReq,
      refparty,
      money_domain: moneyDomain,
      doc_status: docStatus,
      refbankaccount,
    });
    const expenseId = inserted[0];
    if (!expenseId) return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };

    if (subdata.length > 0) await createInExpenseSub(expenseId, subdata, trx);
    if (payCheque.length > 0) await createInPayCheque(bodyData.token, expenseId, { payCheque }, trx);
    if (refExpenseReq && hasExpenseRecorded) {
      await trx('expensereq').where('id', refExpenseReq).update({ expense_recorded: 1 });
    }

    return {
      status: 'successfully',
      message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
      lastid: expenseId,
    };
  });
}

async function update(id, bodyData) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found' };
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };

  const existing = await db(tableName).where('id', id).first();
  if (!existing) return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };

  const updateFields = {};
  if (typeof bodyData.docno !== 'undefined') updateFields.docno = bodyData.docno;
  if (typeof bodyData.docdate !== 'undefined') updateFields.docdate = bodyData.docdate;
  if (typeof bodyData.detail !== 'undefined') updateFields.detail = bodyData.detail || '';
  if (typeof bodyData.remark !== 'undefined') updateFields.remark = bodyData.remark || '';
  if (typeof bodyData.refbudgetsource !== 'undefined' || typeof bodyData.refBudgetSource !== 'undefined') {
    const nextBs = parsePositiveInt(bodyData.refbudgetsource ?? bodyData.refBudgetSource);
    if (!nextBs) {
      return { status: 'error', message: 'refbudgetsource ต้องไม่ว่าง — ระบุแหล่งเงิน' };
    }
    const bsRow = await db('budgetsource').where('id', nextBs).first('id');
    if (!bsRow) {
      return { status: 'error', message: 'ไม่พบแหล่งเงินที่ระบุ' };
    }
    updateFields.refbudgetsource = nextBs;
  }
  if (typeof bodyData.refmember !== 'undefined') updateFields.refmember = bodyData.refmember || null;
  if (
    typeof bodyData.refexpensereq !== 'undefined' ||
    typeof bodyData.refExpenseReq !== 'undefined' ||
    typeof bodyData.ref_expense_req !== 'undefined'
  ) {
    const nextReq = parseOptionalExpenseReqId(bodyData);
    if (nextReq) {
      const req = await db('expensereq').where('id', nextReq).first('id', 'approval_status');
      if (!req) return { status: 'error', message: 'ไม่พบใบขอเบิกที่อ้างอิง' };
      if (req.approval_status !== 'approved') {
        return { status: 'error', message: 'ใบขอเบิกที่อ้างอิงยังไม่อนุมัติ' };
      }
      const used = await db(tableName)
        .where('refexpensereq', nextReq)
        .whereNot('id', id)
        .whereNotIn('doc_status', ['draft'])
        .first('id');
      if (used) {
        return { status: 'error', message: 'ใบขอเบิกนี้ถูกนำไปบันทึกเบิกจริงแล้ว' };
      }
    }
    updateFields.refexpensereq = nextReq;
  }
  if (typeof bodyData.money_domain !== 'undefined' || typeof bodyData.moneyDomain !== 'undefined') {
    updateFields.money_domain = parseMoneyDomain(bodyData.money_domain || bodyData.moneyDomain);
  }
  if (typeof bodyData.change_reason !== 'undefined' || typeof bodyData.changeReason !== 'undefined') {
    updateFields.change_reason = bodyData.change_reason || bodyData.changeReason || null;
  }

  if (typeof bodyData.doc_status !== 'undefined' || typeof bodyData.docStatus !== 'undefined') {
    const nextStatus = parseDocStatus(bodyData.doc_status || bodyData.docStatus);
    if (!nextStatus) return { status: 'error', message: 'สถานะเอกสารไม่ถูกต้อง' };
    if (!validateStatusTransition(existing.doc_status, nextStatus)) {
      return { status: 'error', message: `ไม่สามารถเปลี่ยนสถานะจาก ${existing.doc_status} เป็น ${nextStatus}` };
    }
    updateFields.doc_status = nextStatus;
  }

  const refparty = await resolvePartyId(bodyData);
  if (refparty !== null || typeof bodyData.refparty !== 'undefined' || typeof bodyData.partyname !== 'undefined') {
    updateFields.refparty = refparty;
  }

  if (typeof bodyData.payCheque !== 'undefined') {
    const payRows = parseJsonArray(bodyData.payCheque);
    updateFields.chequeamount = parseFloat(payRows.reduce((sum, row) => sum + parseAmount(row?.chequeamount), 0).toFixed(2));
  }
  if (typeof bodyData.bankamount !== 'undefined') {
    updateFields.bankamount = parseFloat(parseAmount(bodyData.bankamount).toFixed(2));
  }
  if (typeof bodyData.refbankaccount !== 'undefined' || typeof bodyData.refBankAccount !== 'undefined') {
    updateFields.refbankaccount = parseOptionalBankAccountId({
      refbankaccount: bodyData.refbankaccount ?? bodyData.refBankAccount,
    });
  }

  let parsedSubdata = null;
  if (typeof bodyData.subdata !== 'undefined') {
    parsedSubdata = parseJsonArray(bodyData.subdata);
    const moneyDomainForValidate =
      typeof bodyData.money_domain !== 'undefined' || typeof bodyData.moneyDomain !== 'undefined'
        ? parseMoneyDomain(bodyData.money_domain || bodyData.moneyDomain)
        : existing.money_domain;
    const expenseHeaderCtxValidate = {
      refbankaccount:
        typeof bodyData.refbankaccount !== 'undefined' || typeof bodyData.refBankAccount !== 'undefined'
          ? parseOptionalBankAccountId(bodyData)
          : existing.refbankaccount,
      refbudgetsource:
        typeof bodyData.refbudgetsource !== 'undefined' || typeof bodyData.refBudgetSource !== 'undefined'
          ? (bodyData.refbudgetsource ?? bodyData.refBudgetSource ?? null)
          : existing.refbudgetsource,
    };
    try {
      await assertExpenseSubRowsForReporting(parsedSubdata, moneyDomainForValidate, expenseHeaderCtxValidate);
    } catch (e) {
      return { status: 'error', message: e.message || String(e) };
    }
    updateFields.amount = parseFloat(parsedSubdata.reduce((sum, row) => sum + parseAmount(row?.amount), 0).toFixed(2));
  }

  const hasProtectedFieldChange = Object.keys(updateFields).some((key) => IMMUTABLE_AFTER_POSTED.has(key));
  if ((existing.doc_status === 'approved' || existing.doc_status === 'posted') && hasProtectedFieldChange && !updateFields.change_reason) {
    return { status: 'error', message: 'ต้องระบุเหตุผลการแก้ไข (change_reason)' };
  }
  if (
    Object.keys(updateFields).length === 0 &&
    typeof bodyData.subdata === 'undefined' &&
    typeof bodyData.payCheque === 'undefined'
  ) {
    return { status: 'error', message: 'ไม่มีข้อมูลสำหรับอัปเดต' };
  }

  const expenseSubTable = typeof bodyData.subdata !== 'undefined'
    ? await resolveExpenseSubTableName()
    : null;
  const payChequeTable = typeof bodyData.payCheque !== 'undefined'
    ? await resolvePayChequeTableName()
    : null;
  const shouldMarkExpenseReq = updateFields.refexpensereq && updateFields.doc_status === 'posted'
    && await db.schema.hasColumn('expensereq', 'expense_recorded');

  return db.transaction(async (trx) => {
    if (Object.keys(updateFields).length > 0) {
      await trx(tableName).where('id', id).update(updateFields);
      if (shouldMarkExpenseReq) {
        await trx('expensereq').where('id', updateFields.refexpensereq).update({ expense_recorded: 1 });
      }
    }

    if (typeof bodyData.subdata !== 'undefined' && parsedSubdata !== null) {
      await trx(expenseSubTable).where('refexpense', id).delete();
      if (parsedSubdata.length > 0) {
        await createInExpenseSub(id, parsedSubdata, trx);
      }
    }

    if (typeof bodyData.payCheque !== 'undefined') {
      await trx(payChequeTable).where('refexpense', id).delete();
      const payRows = parseJsonArray(bodyData.payCheque);
      if (payRows.length > 0) {
        await createInPayCheque(bodyData.token, id, { payCheque: payRows }, trx);
      }
    }

    return { status: 'successfully', message: 'อัปเดตข้อมูลเรียบร้อยแล้ว' };
  });
}

async function remove(id, bodyData) {
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (!bodyData?.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };

  const existing = await db(tableName).where('id', id).first();
  if (!existing) {
    return {
      status: 'unsuccessful',
      message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ',
    };
  }
  if (existing.doc_status === 'posted') {
    return { status: 'error', message: 'เอกสารถูกโพสต์แล้ว ไม่อนุญาตให้ลบ' };
  }

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
  remove
}
