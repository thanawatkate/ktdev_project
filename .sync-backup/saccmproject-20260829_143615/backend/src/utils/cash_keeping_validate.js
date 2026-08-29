const db = require('../configs/db.config');
const { classifyPocket } = require('../sacc_register/services/offbudget_register.service');
const { getCurrentFiscalYearBuddhist } = require('./fiscal_year.util');

const POCKET_CASH = 'เงินสด';
const POCKET_BANK = 'เงินฝากธนาคาร';

function parseAmount(v) {
  const n = parseFloat(String(v ?? '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : 0;
}

function masterCodeFromBudgetCode(code) {
  const c = String(code || '').toUpperCase();
  if (c.includes('GOV')) return 'GOV';
  if (c.includes('NONGOV')) return 'NONGOV';
  return null;
}

function resolveFundKind({ budgetMaster, offBudgetCode }) {
  const master = (budgetMaster || '').toUpperCase();
  if (master === 'GOV') return null;
  const ob = (offBudgetCode || '').toUpperCase();
  if (ob === 'OB-09') return 'lunch';
  if (ob === 'OB-11') return 'kosor';
  return 'school_revenue';
}

async function loadSchoolSize() {
  try {
    const row = await db('school_profile').first('school_size');
    const s = (row?.school_size || 'small').toString().toLowerCase();
    return s === 'big' ? 'big' : 'small';
  } catch (_) {
    return 'small';
  }
}

async function sumPocketsAsOf(dateEnd, fundKind) {
  const pockets = { [POCKET_CASH]: 0, [POCKET_BANK]: 0 };
  const incomeQ = db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .leftJoin('budgetsource as bs', 'i.refbudgetsource', 'bs.id')
    .leftJoin('incometype as it', 'isub.refincometype', 'it.id')
    .where('i.docdate', '<=', dateEnd)
    .where('i.doc_status', 'posted');
  const expenseQ = db('expense as e')
    .leftJoin('expensesub as esub', 'e.id', 'esub.refexpense')
    .leftJoin('moneytype as mt', 'esub.refmoneytype', 'mt.id')
    .leftJoin('budgetsource as bs', 'e.refbudgetsource', 'bs.id')
    .leftJoin('incometype as it', 'esub.refincometype', 'it.id')
    .where('e.docdate', '<=', dateEnd)
    .where('e.doc_status', 'posted');

  if (fundKind) {
    const filterFn = (qb) => {
      qb.where(function () {
        this.where('bs.code', 'like', '%NONGOV%').orWhere('bs.code', 'like', '%SCH%');
      });
    };
    incomeQ.andWhere(filterFn);
    expenseQ.andWhere(filterFn);
  }

  const inRows = await incomeQ
    .select('mt.name as mt_name', db.raw('COALESCE(SUM(isub.amount),0) as total'))
    .groupBy('mt.name');
  const outRows = await expenseQ
    .select('mt.name as mt_name', db.raw('COALESCE(SUM(esub.amount),0) as total'))
    .groupBy('mt.name');

  for (const r of inRows) {
    const p = classifyPocket(r.mt_name);
    if (p === POCKET_CASH || p === POCKET_BANK) pockets[p] += parseFloat(r.total) || 0;
  }
  for (const r of outRows) {
    const p = classifyPocket(r.mt_name);
    if (p === POCKET_CASH || p === POCKET_BANK) pockets[p] -= parseFloat(r.total) || 0;
  }
  return pockets;
}

/**
 * ตรวจวงเงินเก็บรักษาก่อนบันทึกรายการที่สถานะ posted
 * @throws Error พร้อมข้อความภาษาไทย
 */
async function assertCashKeepingOnPost({
  docdate,
  subdata,
  budgetSourceId,
  docStatus,
  transactionType = 'income',
}) {
  const status = (docStatus || 'posted').toString().toLowerCase();
  if (status !== 'posted') return;

  const bs = await db('budgetsource').where('id', budgetSourceId).first('id', 'code');
  if (!bs) return;

  const master = masterCodeFromBudgetCode(bs.code);
  let offCode = null;
  const subs = Array.isArray(subdata) ? subdata : [];
  for (const row of subs) {
    const itId = row.refincometype ?? row.refIncomeType ?? row.ref_incometype;
    if (!itId) continue;
    const it = await db('incometype').where('id', itId).orWhere('code', itId).first('code');
    if (it?.code) {
      offCode = it.code;
      break;
    }
  }

  const fundKind = resolveFundKind({ budgetMaster: master, offBudgetCode: offCode });
  if (!fundKind) return;

  const d = new Date(docdate || Date.now());
  const dateEnd = Number.isNaN(d.getTime())
    ? new Date().toISOString().slice(0, 10)
    : d.toISOString().slice(0, 10);
  const fy =
    d.getMonth() + 1 >= 10 ? d.getFullYear() + 544 : d.getFullYear() + 543;
  const schoolSize = await loadSchoolSize();
  const limit = await db('cash_keeping_limit')
    .where({ fiscal_year: String(fy), fund_kind: fundKind, school_size: schoolSize, use: 'Y' })
    .first();
  if (!limit) return;

  const pockets = await sumPocketsAsOf(dateEnd, fundKind);
  const sign = transactionType === 'expense' ? -1 : 1;
  let deltaCash = 0;
  let deltaBank = 0;
  for (const row of subs) {
    const amt = parseAmount(row.amount) * sign;
    const mtId = row.refmoneytype ?? row.refMoneyType;
    let mtName = '';
    if (mtId) {
      const mt = await db('moneytype').where('id', mtId).first('name');
      mtName = mt?.name || '';
    }
    const pocket = classifyPocket(mtName);
    if (pocket === POCKET_CASH) deltaCash += amt;
    else if (pocket === POCKET_BANK) deltaBank += amt;
  }

  const projectedCash = (pockets[POCKET_CASH] || 0) + deltaCash;
  const projectedBank = (pockets[POCKET_BANK] || 0) + deltaBank;
  const cashMax = parseFloat(limit.cash_max) || 0;
  const bankMax = parseFloat(limit.bank_max) || 0;

  if (projectedCash > cashMax + 0.009) {
    throw new Error(
      `ยอดเงินสดเก็บรักษาเกินวงเงิน (${fundKind}): หลังบันทึก ${projectedCash.toFixed(2)} บาท สูงกว่าสูงสุด ${cashMax.toFixed(2)} บาท — ต้องนำฝากหรือนำส่งตามคู่มือการเงิน`,
    );
  }
  if (projectedBank > bankMax + 0.009) {
    throw new Error(
      `ยอดเงินฝากธนาคารเก็บรักษาเกินวงเงิน (${fundKind}): หลังบันทึก ${projectedBank.toFixed(2)} บาท สูงกว่าสูงสุด ${bankMax.toFixed(2)} บาท`,
    );
  }
}

module.exports = {
  assertCashKeepingOnPost,
  resolveFundKind,
};
