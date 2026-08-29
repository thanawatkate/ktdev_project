const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { createIncomeSub } = require('../../sacc_incomesub/controllers/incomesub.controller');
const { createdocno } = require('../../sacc_docgroup/services/saccdocgroup.service');
const { assertIncomeSubRowsForReporting } = require('../../utils/ledger_subline_validate');
const { assertCashKeepingOnPost } = require('../../utils/cash_keeping_validate');

const tableName = 'income';

const IMMUTABLE_AFTER_POSTED = new Set([
  'docno',
  'docdate',
  'amount',
  'detail',
  'remark',
  'refuser',
  'refmoneytype',
  'refbudgetsource',
  'refparty',
  'money_domain',
  'refbankaccount',
  'bank_reference',
]);

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

function parseIncomeMoneyDomain(raw) {
  const v = (raw || '').toString().trim().toLowerCase();
  if (v === 'budget' || v === 'off_budget' || v === 'treasury_income') return v;
  return null;
}

function parseDocStatus(raw) {
  const v = (raw || '').toString().trim().toLowerCase();
  if (v === 'draft' || v === 'approved' || v === 'posted') return v;
  return null;
}

function normalizeOptionalText(raw) {
  if (raw === null || typeof raw === 'undefined') return null;
  const text = String(raw).trim();
  return text.length > 0 ? text : null;
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

function inferMoneyDomainFromIncometypeCode(code) {
  const c = String(code || '').trim().toUpperCase();
  if (c.startsWith('OB-')) return 'off_budget';
  if (['01', '02', '03', '04', '05'].includes(c)) return 'budget';
  if (c === 'TREASURY' || c.startsWith('TR-')) return 'treasury_income';
  return 'off_budget';
}

function parsePositiveInt(v) {
  const n = parseInt(String(v ?? '').trim(), 10);
  return Number.isInteger(n) && n > 0 ? n : null;
}

async function resolveIncometypeMeta(raw) {
  const n = parsePositiveInt(raw);
  if (n) {
    const row = await db('incometype').where('id', n).first('id', 'code');
    if (row) return row;
  }
  const s = String(raw ?? '').trim();
  if (!s) return null;
  let row = await db('incometype').where('code', s).first('id', 'code');
  if (row) return row;
  const m = /^income_type_(.+)$/i.exec(s);
  if (m) {
    row = await db('incometype').where('code', m[1]).first('id', 'code');
    if (row) return row;
  }
  return null;
}

async function inferMoneyDomainFromRefs(bodyData, subdataArr) {
  const explicit = parseIncomeMoneyDomain(bodyData.money_domain || bodyData.moneyDomain);
  if (explicit) return explicit;
  const raw =
    bodyData.refincometype ??
    bodyData.refIncomeType ??
    (subdataArr[0] && (subdataArr[0].refincometype ?? subdataArr[0].refIncomeType));
  const meta = await resolveIncometypeMeta(raw);
  if (!meta || !meta.code) return null;
  return inferMoneyDomainFromIncometypeCode(meta.code);
}

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(`${tableName} as i`)
    .leftJoin('party as p', 'i.refparty', 'p.id')
    .select('i.*', 'p.name as party_name')
    .orderBy('i.created', 'desc')
    .limit(config.listPerPage)
    .offset(offset);
  const data = helper.emptyOrRows(rows);
  const meta = { page };
  return { data, meta };
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
    .andWhereIn('role', ['payer', 'both'])
    .first();
  if (existing) return existing.id;

  const inserted = await db('party').insert({
    name: partyName,
    role: 'payer',
    isactive: true,
  });

  return inserted[0] || null;
}

async function create(bodyData) {
  let detail = bodyData.detail;
  let remarks = bodyData.remark;
  let docdate = bodyData.docdate;
  let docNo = bodyData.docno;

  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }
  if (detail === 'undefined') detail = '';
  if (remarks === 'undefined') remarks = '';
  if (bodyData.refuser === '' || typeof bodyData.refuser === 'undefined') {
    return { status: 'error', message: 'refuser require ' };
  }
  if (bodyData.subdata === '' || typeof bodyData.subdata === 'undefined') {
    return { status: 'error', message: 'subdata require ' };
  }

  if (docdate === 'undefined') {
    docdate = new Date();
  }

  await createdocno({ tablename: 'income', docdate }).then((res) => {
    docNo = res;
  });

  if (docNo === '') {
    return { status: 'error', message: 'docno require ' };
  }
  if (typeof docNo === 'undefined') {
    return { status: 'error', message: 'docno require ' };
  }

  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const refBudgetSourceId = parsePositiveInt(bodyData.refbudgetsource ?? bodyData.refBudgetSource);
  if (!refBudgetSourceId) {
    return { status: 'error', message: 'refbudgetsource require — ระบุแหล่งเงินที่หัวเอกสาร' };
  }
  const bsRow = await db('budgetsource').where('id', refBudgetSourceId).first('id');
  if (!bsRow) {
    return { status: 'error', message: 'ไม่พบแหล่งเงินที่ระบุ' };
  }

  let subdata;
  try {
    subdata = JSON.parse(bodyData.subdata);
  } catch (e) {
    return { status: 'error', message: 'subdata JSON ไม่ถูกต้อง' };
  }

  const incomeHeaderCtx = {
    refbankaccount: bodyData.refbankaccount ?? bodyData.refBankAccount,
    refbudgetsource: bodyData.refbudgetsource ?? bodyData.refBudgetSource,
  };
  try {
    await assertIncomeSubRowsForReporting(subdata, incomeHeaderCtx);
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }

  let amount = 0;
  for (let index = 0; index < subdata.length; index += 1) {
    for (const obj in subdata[index]) {
      if (obj === 'amount') {
        amount += Number(subdata[index][obj]);
      }
    }
  }

  const refparty = await resolvePartyId(bodyData);

  const refbankaccount = (() => {
    const raw = bodyData.refbankaccount ?? bodyData.refBankAccount;
    const n = parseInt(String(raw ?? '').trim(), 10);
    return Number.isFinite(n) && n > 0 ? n : null;
  })();

  const docdateVal = (() => {
    if (!docdate || docdate === 'undefined') return new Date();
    const d = new Date(docdate);
    return Number.isNaN(d.getTime()) ? new Date() : d;
  })();

  const moneyDomain = (await inferMoneyDomainFromRefs(bodyData, subdata)) || null;
  const docStatus = parseDocStatus(bodyData.doc_status || bodyData.docStatus) || 'posted';
  const now = new Date();
  const postedAt = docStatus === 'posted' ? now : null;

  try {
    await assertCashKeepingOnPost({
      docdate: docdateVal,
      subdata,
      budgetSourceId: refBudgetSourceId,
      docStatus,
      transactionType: 'income',
    });
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }

  const insertRow = {
    amount: parseFloat(amount.toFixed(2)),
    docno: docNo,
    docdate: docdateVal,
    detail: detail || '',
    remark: remarks || '',
    bank_reference: normalizeOptionalText(
      bodyData.bank_reference ?? bodyData.bankReference,
    ),
    refuser: bodyData.refuser || null,
    refmoneytype: bodyData.refmoneytype || null,
    refbudgetsource: refBudgetSourceId,
    refparty,
    refbankaccount,
    money_domain: moneyDomain,
    doc_status: docStatus,
    posted_at: postedAt,
  };

  return db.transaction(async (trx) => {
    const result = await trx(tableName).insert(insertRow);

    if (!result[0] || result[0] <= 0) {
      return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
    }

    const insertSub = await createIncomeSub(result[0], bodyData.subdata, incomeHeaderCtx, trx);

    return {
      status: 'successfully',
      message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
      lastId: insertSub,
    };
  });
}

async function update(id, bodyData) {
  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }

  if (id === '' || typeof id === 'undefined') {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }

  const result = await db(tableName).where('id', '=', id).select();
  if (result.length < 1) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }

  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const existing = result[0];
  const fliedUpdate = {};

  if (typeof bodyData.detail !== 'undefined') {
    fliedUpdate.detail = bodyData.detail || '';
  }
  if (typeof bodyData.remark !== 'undefined') {
    fliedUpdate.remark = bodyData.remark || '';
  }
  if (typeof bodyData.bank_reference !== 'undefined' || typeof bodyData.bankReference !== 'undefined') {
    fliedUpdate.bank_reference = normalizeOptionalText(
      bodyData.bank_reference ?? bodyData.bankReference,
    );
  }
  if (typeof bodyData.refmoneytype !== 'undefined') {
    fliedUpdate.refmoneytype = bodyData.refmoneytype || null;
  }
  if (typeof bodyData.refbudgetsource !== 'undefined' || typeof bodyData.refBudgetSource !== 'undefined') {
    const nextBs = parsePositiveInt(bodyData.refbudgetsource ?? bodyData.refBudgetSource);
    if (!nextBs) {
      return { status: 'error', message: 'refbudgetsource ต้องไม่ว่าง — ระบุแหล่งเงินที่หัวเอกสาร' };
    }
    const bsOk = await db('budgetsource').where('id', nextBs).first('id');
    if (!bsOk) {
      return { status: 'error', message: 'ไม่พบแหล่งเงินที่ระบุ' };
    }
    fliedUpdate.refbudgetsource = nextBs;
  }
  if (typeof bodyData.refuser !== 'undefined') {
    fliedUpdate.refuser = bodyData.refuser || null;
  }
  if (typeof bodyData.docdate !== 'undefined') {
    const d = new Date(bodyData.docdate);
    if (!Number.isNaN(d.getTime())) fliedUpdate.docdate = d;
  }
  if (typeof bodyData.docno !== 'undefined') {
    fliedUpdate.docno = bodyData.docno;
  }
  if (typeof bodyData.amount !== 'undefined') {
    fliedUpdate.amount = parseFloat(parseAmount(bodyData.amount).toFixed(2));
  }
  if (typeof bodyData.refbankaccount !== 'undefined' || typeof bodyData.refBankAccount !== 'undefined') {
    const raw = bodyData.refbankaccount ?? bodyData.refBankAccount;
    const n = parseInt(String(raw ?? '').trim(), 10);
    fliedUpdate.refbankaccount = Number.isFinite(n) && n > 0 ? n : null;
  }
  if (typeof bodyData.money_domain !== 'undefined' || typeof bodyData.moneyDomain !== 'undefined') {
    fliedUpdate.money_domain = parseIncomeMoneyDomain(bodyData.money_domain || bodyData.moneyDomain);
  }
  if (typeof bodyData.change_reason !== 'undefined' || typeof bodyData.changeReason !== 'undefined') {
    fliedUpdate.change_reason = bodyData.change_reason || bodyData.changeReason || null;
  }

  if (typeof bodyData.doc_status !== 'undefined' || typeof bodyData.docStatus !== 'undefined') {
    const nextStatus = parseDocStatus(bodyData.doc_status || bodyData.docStatus);
    if (!nextStatus) {
      return { status: 'error', message: 'สถานะเอกสารไม่ถูกต้อง' };
    }
    const cur = (existing.doc_status || 'posted').toString().trim().toLowerCase();
    if (!validateStatusTransition(cur, nextStatus)) {
      return { status: 'error', message: `ไม่สามารถเปลี่ยนสถานะจาก ${cur} เป็น ${nextStatus}` };
    }
    fliedUpdate.doc_status = nextStatus;
    if (nextStatus === 'posted') {
      fliedUpdate.posted_at = new Date();
    }
  }

  const refparty = await resolvePartyId(bodyData);
  if (refparty !== null || typeof bodyData.refparty !== 'undefined' || typeof bodyData.partyname !== 'undefined') {
    fliedUpdate.refparty = refparty;
  }

  let parsedSubdata = null;
  let mergedIncomeHeader = null;
  if (typeof bodyData.subdata !== 'undefined') {
    try {
      parsedSubdata = JSON.parse(bodyData.subdata);
    } catch (e) {
      return { status: 'error', message: 'subdata JSON ไม่ถูกต้อง' };
    }
    mergedIncomeHeader = {
      refbankaccount: bodyData.refbankaccount ?? bodyData.refBankAccount ?? existing.refbankaccount,
      refbudgetsource: bodyData.refbudgetsource ?? bodyData.refBudgetSource ?? existing.refbudgetsource,
    };
    try {
      await assertIncomeSubRowsForReporting(parsedSubdata, mergedIncomeHeader);
    } catch (e) {
      return { status: 'error', message: e.message || String(e) };
    }
    let sum = 0;
    for (let i = 0; i < parsedSubdata.length; i += 1) {
      sum += parseAmount(parsedSubdata[i]?.amount);
    }
    fliedUpdate.amount = parseFloat(sum.toFixed(2));
  }

  const hasProtectedFieldChange = Object.keys(fliedUpdate).some((key) => IMMUTABLE_AFTER_POSTED.has(key));
  const curStatus = (existing.doc_status || 'posted').toString().trim().toLowerCase();
  if ((curStatus === 'approved' || curStatus === 'posted') && hasProtectedFieldChange && !fliedUpdate.change_reason) {
    return { status: 'error', message: 'ต้องระบุเหตุผลการแก้ไข (change_reason)' };
  }

  if (Object.keys(fliedUpdate).length === 0 && typeof bodyData.subdata === 'undefined') {
    return { status: 'error', message: 'ไม่มีข้อมูลสำหรับอัปเดต' };
  }

  return db.transaction(async (trx) => {
    if (Object.keys(fliedUpdate).length > 0) {
      await trx(tableName).where('id', '=', id).update(fliedUpdate);
    }

    if (typeof bodyData.subdata !== 'undefined' && parsedSubdata !== null) {
      await trx('incomesub').where('refincome', id).delete();
      if (parsedSubdata.length > 0) {
        await createIncomeSub(id, bodyData.subdata, mergedIncomeHeader, trx);
      }
    }

    return { status: 'successfully', message: 'อัปเดตข้อมูลเรียบร้อยแล้ว' };
  });
}

async function remove(id, bodyData) {
  if (id === '' || typeof id === 'undefined') {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }
  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }
  let del = await db(tableName).where('id', '=', id).delete();
  if (del <= 0 && bodyData.docno) {
    del = await db(tableName).where('docno', '=', bodyData.docno).delete();
  }

  if (del > 0) {
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
