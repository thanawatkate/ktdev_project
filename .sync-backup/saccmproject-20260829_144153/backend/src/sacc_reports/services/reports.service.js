const db = require('../../configs/db.config');
const {
  getCurrentFiscalYearBuddhist,
  fiscalYearRangeFromBuddhist,
} = require('../../utils/fiscal_year.util');
const { EXPENSE_DOC_TS_SQL, EXPENSE_DOC_TS_BARE } = require('../../utils/expense_doc_timestamp');

function httpError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

function parseReportFiscalYear(raw) {
  if (raw == null || raw === '') return getCurrentFiscalYearBuddhist();
  const fy = Number.parseInt(raw, 10);
  if (!Number.isInteger(fy) || String(raw).trim() !== String(fy) || fy < 2500 || fy > 2700) {
    throw httpError(400, 'ปีงบประมาณต้องเป็นปี พ.ศ. 2500-2700');
  }
  return fy;
}

function parseReportDate(raw, name) {
  if (raw == null || raw === '') return null;
  const value = String(raw).slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw httpError(400, `${name} ต้องเป็นรูปแบบ YYYY-MM-DD`);
  }
  const parsed = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    throw httpError(400, `${name} ไม่ถูกต้อง`);
  }
  return value;
}

function dayRange(date) {
  return {
    start: date,
    end: `${date} 23:59:59`,
  };
}

/**
 * รายงานสรุปรายรับ-รายจ่าย แยกตามช่วงเวลา
 */
async function getSummaryReport(query = {}) {
  const { date_from, date_to, fiscal_year } = query;
  const fyRange = fiscal_year ? fiscalYearRangeFromBuddhist(parseReportFiscalYear(fiscal_year)) : null;
  const fromDate = parseReportDate(date_from, 'date_from') || fyRange?.startDate;
  const toDate = parseReportDate(date_to, 'date_to') || fyRange?.endDate;
  const toDateEnd = toDate ? `${toDate} 23:59:59` : null;

  let incomeQ = db('income').sum('amount as total').first();
  let expenseQ = db('expense').sum('amount as total').first();
  let loanQ = db('loan').sum('amount as total').first();
  let repayQ = db('repayloan').sum('amount as total').first();

  if (fromDate) {
    incomeQ = incomeQ.where('docdate', '>=', fromDate);
    expenseQ = expenseQ.whereRaw(`${EXPENSE_DOC_TS_BARE} >= ?`, [fromDate]);
    loanQ = loanQ.where('loandate', '>=', fromDate);
    repayQ = repayQ.where('created', '>=', fromDate);
  }
  if (toDateEnd) {
    incomeQ = incomeQ.where('docdate', '<=', toDateEnd);
    expenseQ = expenseQ.whereRaw(`${EXPENSE_DOC_TS_BARE} <= ?`, [toDateEnd]);
    loanQ = loanQ.where('loandate', '<=', toDateEnd);
    repayQ = repayQ.where('created', '<=', toDateEnd);
  }

  const [income, expense, loan, repay] = await Promise.all([incomeQ, expenseQ, loanQ, repayQ]);

  const totalIncome = parseFloat(income?.total) || 0;
  const totalExpense = parseFloat(expense?.total) || 0;
  const totalLoan = parseFloat(loan?.total) || 0;
  const totalRepay = parseFloat(repay?.total) || 0;
  const balance = totalIncome - totalExpense;

  return {
    data: {
      total_income: totalIncome,
      total_expense: totalExpense,
      total_loan: totalLoan,
      total_repay: totalRepay,
      balance,
      net_cash_flow: totalIncome - totalExpense + totalRepay - totalLoan,
    }
  };
}

/**
 * รายงานสรุปรายรับ แยกตามเดือน
 */
async function getIncomeByMonth(query = {}) {
  const { fiscal_year } = query;
  const year = parseReportFiscalYear(fiscal_year);
  const range = fiscalYearRangeFromBuddhist(year);
  if (!range) return { data: [] };
  const rangeEnd = `${range.endDate} 23:59:59`;

  const rows = await db('income')
    .select(
      db.raw("DATE_FORMAT(docdate, '%Y-%m') as month"),
      db.raw('SUM(amount) as total'),
      db.raw('COUNT(id) as count'),
    )
    .where('docdate', '>=', range.startDate)
    .where('docdate', '<=', rangeEnd)
    .groupByRaw("DATE_FORMAT(docdate, '%Y-%m')")
    .orderBy('month', 'asc');

  return { data: rows };
}

/**
 * รายงานสรุปรายจ่าย แยกตามเดือน
 */
async function getExpenseByMonth(query = {}) {
  const { fiscal_year } = query;
  const year = parseReportFiscalYear(fiscal_year);
  const range = fiscalYearRangeFromBuddhist(year);
  if (!range) return { data: [] };
  const rangeEnd = `${range.endDate} 23:59:59`;

  const rows = await db('expense')
    .select(
      db.raw(`DATE_FORMAT(${EXPENSE_DOC_TS_BARE}, '%Y-%m') as month`),
      db.raw('SUM(amount) as total'),
      db.raw('COUNT(id) as count'),
    )
    .whereRaw(`${EXPENSE_DOC_TS_BARE} >= ?`, [range.startDate])
    .whereRaw(`${EXPENSE_DOC_TS_BARE} <= ?`, [rangeEnd])
    .groupByRaw(`DATE_FORMAT(${EXPENSE_DOC_TS_BARE}, '%Y-%m')`)
    .orderBy('month', 'asc');

  return { data: rows };
}

/**
 * รายงานสรุปแยกตามแหล่งเงิน (งบประมาณ)
 */
async function getExpenseByBudgetSource(query = {}) {
  const { fiscal_year } = query;
  const year = fiscal_year ? parseReportFiscalYear(fiscal_year) : null;

  const expenseAgg = db('expense')
    .select('refbudgetsource')
    .sum({ used_expense: 'amount' })
    .groupBy('refbudgetsource')
    .as('ea');

  const incomeAgg = db('income')
    .select('refbudgetsource')
    .sum({ received_income: 'amount' })
    .groupBy('refbudgetsource')
    .as('ia');

  let q = db('budgetsource as b')
    .leftJoin(expenseAgg, 'b.id', 'ea.refbudgetsource')
    .leftJoin(incomeAgg, 'b.id', 'ia.refbudgetsource')
    .select(
      'b.id',
      'b.code',
      'b.name',
      'b.budget_type',
      'b.budget_amount',
      'b.brought_forward_amount',
      'b.fiscal_year',
      db.raw('COALESCE(ea.used_expense, 0) as used_expense'),
      db.raw('COALESCE(ia.received_income, 0) as received_income'),
    )
    .where('b.use', 'Y')
    .orderBy('b.fiscal_year', 'desc')
    .orderBy('b.code', 'asc');

  if (year) q = q.where('b.fiscal_year', String(year));

  const rows = await q;
  return {
    data: rows.map((r) => {
      const bf = parseFloat(r.brought_forward_amount) || 0;
      const alloc = parseFloat(r.budget_amount) + bf;
      return {
        ...r,
        remaining: alloc - parseFloat(r.used_expense),
        used_percent:
          alloc > 0
            ? ((parseFloat(r.used_expense) / alloc) * 100).toFixed(2)
            : '0.00',
      };
    }),
  };
}

/**
 * งบทดลอง (Trial Balance) — รายรับ vs รายจ่าย แยกตามประเภท
 */
async function getTrialBalance(query = {}) {
  const { date_from, date_to, fiscal_year } = query;
  const fyRange = fiscal_year ? fiscalYearRangeFromBuddhist(parseReportFiscalYear(fiscal_year)) : null;
  const fromDate = parseReportDate(date_from, 'date_from') || fyRange?.startDate;
  const toDate = parseReportDate(date_to, 'date_to') || fyRange?.endDate;
  const toDateEnd = toDate ? `${toDate} 23:59:59` : null;

  // รายรับแยกตามประเภท
  let incomeByType = db('income as i')
    .leftJoin('moneytype as mt', 'i.refmoneytype', 'mt.id')
    .select(
      'mt.name as type_name',
      db.raw('SUM(i.amount) as total'),
      db.raw('COUNT(i.id) as count'),
    )
    .groupBy('mt.id', 'mt.name')
    .orderBy('total', 'desc');

  // รายจ่ายแยกตามประเภท
  let expenseByType = db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .select(
      'mt.name as type_name',
      db.raw('SUM(es.amount) as total'),
      db.raw('COUNT(e.id) as count'),
    )
    .groupBy('mt.id', 'mt.name')
    .orderBy('total', 'desc');

  if (fromDate) {
    incomeByType = incomeByType.where('i.docdate', '>=', fromDate);
    expenseByType = expenseByType.whereRaw(`${EXPENSE_DOC_TS_SQL} >= ?`, [fromDate]);
  }
  if (toDateEnd) {
    incomeByType = incomeByType.where('i.docdate', '<=', toDateEnd);
    expenseByType = expenseByType.whereRaw(`${EXPENSE_DOC_TS_SQL} <= ?`, [toDateEnd]);
  }

  const [income, expense] = await Promise.all([incomeByType, expenseByType]);
  return { data: { income, expense } };
}

/**
 * รายงานรายวัน (เอกสารรายรับ-รายจ่ายประจำวัน)
 */
async function getDailyTransactions(query = {}) {
  const { date } = query;
  const targetDate = parseReportDate(date, 'date') || new Date().toISOString().slice(0, 10);
  const targetRange = dayRange(targetDate);

  const [incomes, expenses] = await Promise.all([
    db('income as i')
      .leftJoin('users as u', 'i.refuser', 'u.id')
      .leftJoin('moneytype as mt', 'i.refmoneytype', 'mt.id')
      .leftJoin('budgetsource as b', 'i.refbudgetsource', 'b.id')
      .select(
        'i.id', 'i.docno', 'i.docdate', 'i.amount', 'i.detail',
        db.raw("CONCAT(u.name, ' ', u.lastname) as user_name"),
        'mt.name as money_type_name',
        'b.name as budget_source_name',
      )
      .where('i.docdate', '>=', targetRange.start)
      .where('i.docdate', '<=', targetRange.end)
      .orderBy('i.docdate', 'asc'),

    db('expense as e')
      .leftJoin('member as m', 'e.refmember', 'm.id')
      .leftJoin('budgetsource as b', 'e.refbudgetsource', 'b.id')
      .select(
        'e.id', 'e.docno',
        db.raw(`${EXPENSE_DOC_TS_SQL} as docdate`),
        'e.amount', 'e.remark',
        db.raw("CONCAT(COALESCE(m.name,''), ' ', COALESCE(m.lastname,'')) as member_name"),
        'b.name as budget_source_name',
      )
      .whereRaw(`${EXPENSE_DOC_TS_SQL} >= ?`, [targetRange.start])
      .whereRaw(`${EXPENSE_DOC_TS_SQL} <= ?`, [targetRange.end])
      .orderByRaw(`${EXPENSE_DOC_TS_SQL} asc`),
  ]);

  return { data: { date: targetDate, incomes, expenses } };
}

/**
 * รายงานงบประมาณคงเหลือ (Budget Remaining)
 */
async function getBudgetRemaining(query = {}) {
  const { fiscal_year } = query;
  const year = fiscal_year ? parseReportFiscalYear(fiscal_year) : null;
  let q = db('budgetsource')
    .where('use', 'Y')
    .select(
      'id',
      'code',
      'name',
      'budget_type',
      'fiscal_year',
      'budget_amount',
      'brought_forward_amount',
      'used_amount',
      db.raw(
        '((COALESCE(brought_forward_amount,0) + COALESCE(budget_amount,0)) - used_amount) as remaining',
      ),
      db.raw(
        'CASE WHEN (COALESCE(brought_forward_amount,0) + COALESCE(budget_amount,0)) > 0 THEN ROUND((used_amount / (COALESCE(brought_forward_amount,0) + COALESCE(budget_amount,0)) * 100), 2) ELSE 0 END as used_percent',
      ),
    )
    .orderBy('fiscal_year', 'desc')
    .orderBy('code', 'asc');

  if (year) q = q.where('fiscal_year', String(year));
  const rows = await q;
  return { data: rows };
}

module.exports = {
  getSummaryReport,
  getIncomeByMonth,
  getExpenseByMonth,
  getExpenseByBudgetSource,
  getTrialBalance,
  getDailyTransactions,
  getBudgetRemaining,
  parseReportFiscalYear,
  parseReportDate,
};
