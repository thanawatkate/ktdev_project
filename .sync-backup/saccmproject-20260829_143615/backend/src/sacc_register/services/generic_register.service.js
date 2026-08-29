const db = require('../../configs/db.config');
const { EXPENSE_DOC_TS_SQL } = require('../../utils/expense_doc_timestamp');

function parseFiscalYearRange(fiscalYear) {
  const fy = fiscalYear ? parseInt(fiscalYear, 10) : null;
  if (!fy) return null;
  const adYear = fy - 543;
  return {
    start: `${adYear - 1}-10-01`,
    end: `${adYear}-09-30 23:59:59`,
  };
}

function classifyPocket(moneyTypeName) {
  const n = (moneyTypeName || '').toString().trim();
  if (n.includes('ส่วนราชการ') || /agency/i.test(n)) return 'agency';
  if (n.includes('เช็ค') || /cheque/i.test(n)) return 'bank';
  if (n.includes('โอน') || n.includes('ฝากธนาคาร') || n.includes('ธนาคาร') || /transfer|bank/i.test(n)) {
    return 'bank';
  }
  return 'cash';
}

/**
 * ทะเบียนคุมหลักฐานขอเบิก (Withdrawal Evidence Register) — คู่มือหน้า 38
 * อิง expensereq + expensereqsub + budgetsource
 */
async function getEvidenceRegister(query = {}) {
  const range = parseFiscalYearRange(query.fiscal_year);

  const builder = db('expensereq as r')
    .leftJoin('users as u', 'r.refmember', 'u.id') // อาจไม่ได้ใช้ขึ้นกับ schema; ปลอดภัยใช้ leftJoin
    .leftJoin('budgetsource as bs', 'r.refbudgetsource', 'bs.id')
    .select(
      'r.id', 'r.docno', 'r.docdate', 'r.detail', 'r.amount',
      'r.approval_status', 'r.created',
      'bs.name as budget_source_name', 'bs.code as budget_source_code',
    )
    .orderBy('r.docdate', 'asc')
    .orderBy('r.id', 'asc');

  if (range) {
    builder.whereBetween('r.docdate', [
      range.start,
      range.end,
    ]);
  }

  const rows = await builder;
  return { data: rows };
}

/**
 * ทะเบียนคุมใบสำคัญคู่จ่าย (Voucher Register) — คู่มือหน้า 37
 */
async function getVoucherRegister(query = {}) {
  const range = parseFiscalYearRange(query.fiscal_year);

  const builder = db('expense as e')
    .leftJoin('budgetsource as bs', 'e.refbudgetsource', 'bs.id')
    .leftJoin('member as m', 'e.refmember', 'm.id')
    .select(
      'e.id', 'e.docno',
      db.raw(`${EXPENSE_DOC_TS_SQL} as docdate`),
      'e.amount',
      'e.remark', 'e.detail',
      'bs.name as budget_source_name',
      db.raw("CONCAT(COALESCE(m.name,''),' ',COALESCE(m.lastname,'')) as receiver"),
    )
    .orderByRaw(`${EXPENSE_DOC_TS_SQL} asc`)
    .orderBy('e.id', 'asc');

  if (range) {
    builder.whereRaw(`${EXPENSE_DOC_TS_SQL} BETWEEN ? AND ?`, [
      range.start,
      range.end,
    ]);
  }
  const rows = await builder;
  return { data: rows };
}

/**
 * ทะเบียนคุมการจ่ายเช็ค (Cheque Payment Register) — คู่มือหน้า 39
 */
async function getChequeRegister(query = {}) {
  const range = parseFiscalYearRange(query.fiscal_year);

  const builder = db('paycheque as p')
    .leftJoin('chequeaccount as ca', 'p.refchequeaccount', 'ca.id')
    .leftJoin('bank as b', 'ca.refbank', 'b.id')
    .leftJoin('expense as e', 'p.refexpense', 'e.id')
    .select(
      'p.id',
      'p.id as pay_cheque_id',
      'p.chequeno',
      'p.chequeamount',
      'p.remark',
      'p.cleared_at',
      'p.refchequeaccount',
      'p.refexpense',
      db.raw(`${EXPENSE_DOC_TS_SQL} as docdate`),
      db.raw('p.chequeamount as amount'),
      'b.name as bank_name',
      db.raw('COALESCE(ca.chequemame, ca.chequeno) as cheque_account_no'),
      'e.docno as expense_docno',
      'e.detail as expense_detail',
    )
    .orderByRaw(`${EXPENSE_DOC_TS_SQL} asc`)
    .orderBy('p.id', 'asc');

  if (range) {
    builder.whereRaw(`${EXPENSE_DOC_TS_SQL} BETWEEN ? AND ?`, [
      range.start,
      range.end,
    ]);
  }

  const rows = await builder;
  return { data: rows };
}

/**
 * ทะเบียนคุมสัญญายืมเงิน (Loan Register) — คู่มือหน้า 45
 */
async function getLoanRegister(query = {}) {
  const range = parseFiscalYearRange(query.fiscal_year);

  const builder = db('loan as l')
    .leftJoin('member as m', 'l.refmember', 'm.id')
    .leftJoin(
      db('repayloan')
        .select('refloan')
        .sum('amount as repay_total')
        .groupBy('refloan')
        .as('rp'),
      'rp.refloan', 'l.id',
    )
    .select(
      'l.id', 'l.docno', 'l.loandate', 'l.duedate',
      'l.amount as loan_amount',
      'l.opening_outstanding as opening_outstanding',
      'l.remark',
      db.raw("CONCAT(COALESCE(m.name,''),' ',COALESCE(m.lastname,'')) as borrower"),
      db.raw('COALESCE(rp.repay_total, 0) as repay_total'),
      db.raw('(COALESCE(l.amount,0) + COALESCE(l.opening_outstanding,0) - COALESCE(rp.repay_total,0)) as outstanding'),
    )
    .orderBy('l.loandate', 'asc')
    .orderBy('l.id', 'asc');

  if (range) {
    builder.whereBetween('l.loandate', [
      range.start,
      range.end,
    ]);
  }

  const rows = await builder;
  return { data: rows };
}

/**
 * ทะเบียนคุมใบเสร็จรับเงิน — receipt_book + receipt_issue (คู่มือหน้า 35)
 */
async function getReceiptBookRegister(query = {}) {
  const fy = query.fiscal_year ? String(query.fiscal_year) : null;
  const builder = db('receipt_book as rb')
    .leftJoin(
      db('receipt_issue')
        .select('refbook')
        .sum('amount as used_amount')
        .count('id as used_count')
        .where('issue_status', 'used')
        .groupBy('refbook')
        .as('issued'),
      'issued.refbook', 'rb.id',
    )
    .select(
      'rb.id', 'rb.book_no', 'rb.receipt_type',
      'rb.start_no', 'rb.end_no', 'rb.fiscal_year',
      'rb.status', 'rb.received_at', 'rb.received_from', 'rb.remark',
      db.raw('COALESCE(issued.used_amount,0) as used_amount'),
      db.raw('COALESCE(issued.used_count,0) as used_count'),
    )
    .orderBy('rb.fiscal_year', 'desc')
    .orderBy('rb.book_no', 'asc');

  if (fy) builder.where('rb.fiscal_year', fy);

  const books = await builder;
  return { data: books };
}

async function listReceiptIssues(bookId) {
  const rows = await db('receipt_issue as ri')
    .leftJoin('income as i', 'ri.refincome', 'i.id')
    .where('ri.refbook', bookId)
    .select(
      'ri.id', 'ri.receipt_no', 'ri.issued_at', 'ri.issued_to', 'ri.amount',
      'ri.issue_status', 'ri.remark',
      'i.docno as income_docno',
    )
    .orderBy('ri.receipt_no', 'asc');
  return { data: rows };
}

/**
 * ทะเบียนคุมเงินฝากธนาคาร ประเภทกระแสรายวัน (คู่มือหน้า 36)
 */
async function getCurrentAccountRegister(query = {}) {
  const range = parseFiscalYearRange(query.fiscal_year);
  if (!range) return { data: { error: 'fiscal_year ไม่ถูกต้อง' } };

  const openIn = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .where('i.docdate', '<', range.start)
    .where((qb) => {
      qb.whereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%ฝาก%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%ธนาคาร%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%bank%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%โอน%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%เช็ค%'");
    })
    .whereRaw("LOWER(IFNULL(mt.name,'')) NOT LIKE '%ส่วนราชการ%'")
    .sum({ total: 'isub.amount' })
    .first();

  const openOut = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} < ?`, [range.start])
    .where((qb) => {
      qb.whereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%ฝาก%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%ธนาคาร%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%bank%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%โอน%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%เช็ค%'");
    })
    .whereRaw("LOWER(IFNULL(mt.name,'')) NOT LIKE '%ส่วนราชการ%'")
    .sum({ total: 'es.amount' })
    .first();

  const opening = (parseFloat(openIn?.total) || 0) - (parseFloat(openOut?.total) || 0);

  const incomes = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .whereBetween('i.docdate', [range.start, range.end])
    .select('i.docdate', 'i.docno', 'i.detail', 'i.remark', 'isub.amount', 'mt.name as mt_name')
    .orderBy('i.docdate', 'asc')
    .orderBy('i.id', 'asc');

  const expenses = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} BETWEEN ? AND ?`, [range.start, range.end])
    .select(db.raw(`${EXPENSE_DOC_TS_SQL} as docdate`), 'e.docno', 'e.detail', 'e.remark', 'es.amount', 'mt.name as mt_name')
    .orderByRaw(`${EXPENSE_DOC_TS_SQL} asc`)
    .orderBy('e.id', 'asc');

  let running = opening;
  const lines = [];
  const all = [
    ...incomes.map((r) => ({ ...r, _kind: 'in' })),
    ...expenses.map((r) => ({ ...r, _kind: 'out' })),
  ];
  all.sort((a, b) => new Date(a.docdate).getTime() - new Date(b.docdate).getTime());

  for (const r of all) {
    if (classifyPocket(r.mt_name) !== 'bank') continue;
    const amt = parseFloat(r.amount) || 0;
    if (amt <= 0) continue;
    if (r._kind === 'in') running += amt;
    else running -= amt;
    lines.push({
      docdate: r.docdate,
      docno: r.docno || '-',
      detail: r.detail || r.remark || '',
      deposit: r._kind === 'in' ? amt : 0,
      withdraw: r._kind === 'out' ? amt : 0,
      balance: running,
      remark: r.remark || '',
    });
  }

  return {
    data: {
      fiscal_year: parseInt(query.fiscal_year, 10),
      opening,
      lines,
      ending: running,
    },
  };
}

/**
 * สมุดคู่ฝากส่วนราชการผู้เบิก (คู่มือหน้า 43)
 */
async function getAgencyDepositRegister(query = {}) {
  const range = parseFiscalYearRange(query.fiscal_year);
  if (!range) return { data: { error: 'fiscal_year ไม่ถูกต้อง' } };

  const openIn = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .where('i.docdate', '<', range.start)
    .where((qb) => {
      qb.whereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%ส่วนราชการ%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%agency%'");
    })
    .sum({ total: 'isub.amount' })
    .first();

  const openOut = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} < ?`, [range.start])
    .where((qb) => {
      qb.whereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%ส่วนราชการ%'")
        .orWhereRaw("LOWER(IFNULL(mt.name,'')) LIKE '%agency%'");
    })
    .sum({ total: 'es.amount' })
    .first();

  const opening = (parseFloat(openIn?.total) || 0) - (parseFloat(openOut?.total) || 0);

  const incomes = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .leftJoin('party as ip', 'i.refparty', 'ip.id')
    .whereBetween('i.docdate', [range.start, range.end])
    .select('i.docdate', 'i.docno', 'i.detail', 'i.remark', 'ip.name as party_name', 'isub.amount', 'mt.name as mt_name')
    .orderBy('i.docdate', 'asc')
    .orderBy('i.id', 'asc');

  const expenses = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .leftJoin('party as ep', 'e.refparty', 'ep.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} BETWEEN ? AND ?`, [range.start, range.end])
    .select(db.raw(`${EXPENSE_DOC_TS_SQL} as docdate`), 'e.docno', 'e.detail', 'e.remark', 'ep.name as party_name', 'es.amount', 'mt.name as mt_name')
    .orderByRaw(`${EXPENSE_DOC_TS_SQL} asc`)
    .orderBy('e.id', 'asc');

  let running = opening;
  const lines = [];
  const all = [
    ...incomes.map((r) => ({ ...r, _kind: 'in' })),
    ...expenses.map((r) => ({ ...r, _kind: 'out' })),
  ];
  all.sort((a, b) => new Date(a.docdate).getTime() - new Date(b.docdate).getTime());

  for (const r of all) {
    if (classifyPocket(r.mt_name) !== 'agency') continue;
    const amt = parseFloat(r.amount) || 0;
    if (amt <= 0) continue;
    if (r._kind === 'in') running += amt;
    else running -= amt;
    lines.push({
      docdate: r.docdate,
      docno: r.docno || '-',
      deposit: r._kind === 'in' ? amt : 0,
      withdraw: r._kind === 'out' ? amt : 0,
      balance: running,
      party_name: r.party_name || '-',
      remark: r.detail || r.remark || '',
    });
  }

  return {
    data: {
      fiscal_year: parseInt(query.fiscal_year, 10),
      opening,
      lines,
      ending: running,
    },
  };
}

/**
 * ทะเบียนคุมรับและนำส่งเงินรายได้แผ่นดิน (คู่มือหน้า 44)
 */
async function getTreasuryRemitRegister(query = {}) {
  const range = parseFiscalYearRange(query.fiscal_year);
  if (!range) return { data: { error: 'fiscal_year ไม่ถูกต้อง' } };

  const treasuryGroup = await db('moneygroup')
    .where((qb) => qb.where('name', 'like', '%รายได้แผ่นดิน%').orWhere('name', 'like', '%treasury%'))
    .first('id');
  if (!treasuryGroup?.id) {
    return { data: { fiscal_year: parseInt(query.fiscal_year, 10), opening: 0, lines: [], ending: 0 } };
  }

  const treasuryCodes = ['TR-%', 'REV-%', 'TI-%'];

  const incomes = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('incometype as it', 'isub.refincometype', 'it.id')
    .leftJoin('budgetsource as bs', 'i.refbudgetsource', 'bs.id')
    .whereBetween('i.docdate', [range.start, range.end])
    .where((qb) => {
      qb.where('bs.refmoneygroup', treasuryGroup.id)
        .orWhere('it.refmoneygroup', treasuryGroup.id)
        .orWhere((codeQb) => {
          treasuryCodes.forEach((code) => codeQb.orWhere('it.code', 'like', code));
        })
        .orWhere('it.name', 'like', '%รายได้แผ่นดิน%');
    })
    .select('i.docdate', 'i.docno', 'i.detail', 'i.remark', 'isub.amount', 'bs.name as budget_source_name')
    .orderBy('i.docdate', 'asc')
    .orderBy('i.id', 'asc');

  const remits = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('incometype as it', 'es.refincometype', 'it.id')
    .leftJoin('budgetsource as bs', 'e.refbudgetsource', 'bs.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} BETWEEN ? AND ?`, [range.start, range.end])
    .where((qb) => {
      qb.where('bs.refmoneygroup', treasuryGroup.id)
        .orWhere('it.refmoneygroup', treasuryGroup.id)
        .orWhere((codeQb) => {
          treasuryCodes.forEach((code) => codeQb.orWhere('it.code', 'like', code));
        })
        .orWhere('it.name', 'like', '%รายได้แผ่นดิน%');
    })
    .select(db.raw(`${EXPENSE_DOC_TS_SQL} as docdate`), 'e.docno', 'e.detail', 'e.remark', 'es.amount', 'bs.name as budget_source_name')
    .orderByRaw(`${EXPENSE_DOC_TS_SQL} asc`)
    .orderBy('e.id', 'asc');

  const openIn = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('incometype as it', 'isub.refincometype', 'it.id')
    .leftJoin('budgetsource as bs', 'i.refbudgetsource', 'bs.id')
    .where('i.docdate', '<', range.start)
    .where((qb) => {
      qb.where('bs.refmoneygroup', treasuryGroup.id)
        .orWhere('it.refmoneygroup', treasuryGroup.id)
        .orWhere((codeQb) => {
          treasuryCodes.forEach((code) => codeQb.orWhere('it.code', 'like', code));
        })
        .orWhere('it.name', 'like', '%รายได้แผ่นดิน%');
    })
    .sum({ total: 'isub.amount' })
    .first();

  const openOut = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('incometype as it', 'es.refincometype', 'it.id')
    .leftJoin('budgetsource as bs', 'e.refbudgetsource', 'bs.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} < ?`, [range.start])
    .where((qb) => {
      qb.where('bs.refmoneygroup', treasuryGroup.id)
        .orWhere('it.refmoneygroup', treasuryGroup.id)
        .orWhere((codeQb) => {
          treasuryCodes.forEach((code) => codeQb.orWhere('it.code', 'like', code));
        })
        .orWhere('it.name', 'like', '%รายได้แผ่นดิน%');
    })
    .sum({ total: 'es.amount' })
    .first();

  const opening = (parseFloat(openIn?.total) || 0) - (parseFloat(openOut?.total) || 0);
  let running = opening;
  const lines = [];
  const all = [
    ...incomes.map((r) => ({ ...r, _kind: 'in' })),
    ...remits.map((r) => ({ ...r, _kind: 'out' })),
  ];
  all.sort((a, b) => new Date(a.docdate).getTime() - new Date(b.docdate).getTime());

  for (const r of all) {
    const amt = parseFloat(r.amount) || 0;
    if (amt <= 0) continue;
    if (r._kind === 'in') running += amt;
    else running -= amt;
    lines.push({
      docdate: r.docdate,
      docno: r.docno || '-',
      detail: r.detail || r.remark || '',
      budget_source_name: r.budget_source_name || '-',
      received: r._kind === 'in' ? amt : 0,
      remitted: r._kind === 'out' ? amt : 0,
      balance: running,
      remark: r.remark || '',
    });
  }

  return {
    data: {
      fiscal_year: parseInt(query.fiscal_year, 10),
      opening,
      lines,
      ending: running,
    },
  };
}

module.exports = {
  getEvidenceRegister,
  getVoucherRegister,
  getChequeRegister,
  getLoanRegister,
  getReceiptBookRegister,
  getCurrentAccountRegister,
  getAgencyDepositRegister,
  getTreasuryRemitRegister,
  listReceiptIssues,
};
