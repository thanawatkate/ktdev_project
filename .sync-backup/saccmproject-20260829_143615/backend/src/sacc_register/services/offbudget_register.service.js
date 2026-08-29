const db = require('../../configs/db.config');
const {
  getCurrentFiscalYearBuddhist,
  fiscalYearRangeFromBuddhist,
} = require('../../utils/fiscal_year.util');
const { EXPENSE_DOC_TS_SQL } = require('../../utils/expense_doc_timestamp');

/**
 * ทะเบียนคุมเงินนอกงบประมาณ — ตามคู่มือหน้า 40
 * คอลัมน์: วัน เดือน ปี | ที่เอกสาร | รายการ | รับ | จ่าย | คงเหลือ(เงินสด) | คงเหลือ(เงินฝากธนาคาร) | คงเหลือ(เงินฝากส่วนราชการผู้เบิก) | หมายเหตุ
 *
 * ปีงบประมาณ ต.ค. (ปี-1) → ก.ย. (ปี)
 * รวมเดือน + ยอดยกมา + ยอดยกไป + ยอดต้นปี
 */

const POCKET_CASH = 'เงินสด';
const POCKET_BANK = 'เงินฝากธนาคาร';
const POCKET_AGENCY = 'เงินฝากส่วนราชการผู้เบิก';

const THAI_MONTH_NAMES = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

function classifyPocket(moneyTypeName) {
  const n = (moneyTypeName || '').toString().trim();
  if (n.includes('เงินสด') || /^cash$/i.test(n)) return POCKET_CASH;
  if (n.includes('โอน') || n.includes('ฝากธนาคาร') || /transfer|bank/i.test(n)) return POCKET_BANK;
  if (n.includes('ส่วนราชการ') || /agency/i.test(n)) return POCKET_AGENCY;
  if (n.includes('เช็ค') || /cheque/i.test(n)) return POCKET_BANK;
  return POCKET_CASH;
}

/**
 * ดึงข้อมูลรายการรับ-จ่ายของหมวดเงินนอกงบฯ ในช่วงปีงบประมาณ
 * - กรองตาม `incometype.id` (อ้างเป็น category_id)
 * - หรือ `incometype.code` (เช่น OB-01)
 */
async function getOffBudgetLedger(query = {}) {
  const buddhistYear = Number.parseInt(query.fiscal_year, 10) || getCurrentFiscalYearBuddhist();
  const range = fiscalYearRangeFromBuddhist(buddhistYear);
  if (!range) return { data: { error: 'fiscal_year ไม่ถูกต้อง' } };

  const code = query.code ? String(query.code).trim() : '';
  const categoryId = query.category_id ? parseInt(query.category_id, 10) : null;

  // resolve income type
  let incomeType = null;
  if (categoryId) {
    incomeType = await db('incometype').where('id', categoryId).first();
  } else if (code) {
    incomeType = await db('incometype').where('code', code).first();
  }
  if (!incomeType) {
    return { data: { error: 'ไม่พบหมวดเงิน', requested: { code, categoryId } } };
  }

  // INCOME: ผ่าน incomesub.refincometype = ?
  const incomes = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .leftJoin('budgetsource as bs', 'i.refbudgetsource', 'bs.id')
    .where('isub.refincometype', incomeType.id)
    .whereBetween('i.docdate', [range.startDate, `${range.endDate} 23:59:59`])
    .select(
      'i.id', 'i.docno', 'i.docdate', 'i.detail', 'i.remark',
      'isub.amount as amount',
      'mt.name as money_type_name',
      'bs.name as budget_source_name',
    )
    .orderBy('i.docdate', 'asc')
    .orderBy('i.id', 'asc');

  // EXPENSE: ผ่าน expensesub.refincometype = ?
  const expenses = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .leftJoin('budgetsource as bs', 'e.refbudgetsource', 'bs.id')
    .where('es.refincometype', incomeType.id)
    .whereRaw(`${EXPENSE_DOC_TS_SQL} BETWEEN ? AND ?`, [range.startDate, `${range.endDate} 23:59:59`])
    .select(
      'e.id', 'e.docno',
      db.raw(`${EXPENSE_DOC_TS_SQL} as docdate`),
      'e.remark',
      'es.amount as amount',
      'mt.name as money_type_name',
      'bs.name as budget_source_name',
      'es.pay_category as pay_category',
    )
    .orderByRaw(`${EXPENSE_DOC_TS_SQL} asc`)
    .orderBy('e.id', 'asc');

  // ยอดยกมา = ผลรวมก่อน startDate
  const inBeforeRow = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .where('isub.refincometype', incomeType.id)
    .where('i.docdate', '<', range.startDate)
    .select('mt.name as mt_name', db.raw('COALESCE(SUM(isub.amount),0) as total'))
    .groupBy('mt.name');

  const outBeforeRow = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .where('es.refincometype', incomeType.id)
    .whereRaw(`${EXPENSE_DOC_TS_SQL} < ?`, [range.startDate])
    .select('mt.name as mt_name', db.raw('COALESCE(SUM(es.amount),0) as total'))
    .groupBy('mt.name');

  const opening = { [POCKET_CASH]: 0, [POCKET_BANK]: 0, [POCKET_AGENCY]: 0 };
  for (const r of inBeforeRow) opening[classifyPocket(r.mt_name)] += parseFloat(r.total) || 0;
  for (const r of outBeforeRow) opening[classifyPocket(r.mt_name)] -= parseFloat(r.total) || 0;

  // รวมรายการ + คำนวณคงเหลือสะสม
  const events = [];
  for (const i of incomes) {
    events.push({
      kind: 'income',
      docdate: i.docdate,
      docno: i.docno,
      detail: i.detail || '',
      remark: i.remark || '',
      money_type_name: i.money_type_name || '',
      pocket: classifyPocket(i.money_type_name),
      budget_source_name: i.budget_source_name || '',
      amount_in: parseFloat(i.amount) || 0,
      amount_out: 0,
    });
  }
  for (const e of expenses) {
    events.push({
      kind: 'expense',
      docdate: e.docdate,
      docno: e.docno,
      detail: e.remark || '',
      remark: e.remark || '',
      money_type_name: e.money_type_name || '',
      pocket: classifyPocket(e.money_type_name),
      budget_source_name: e.budget_source_name || '',
      amount_in: 0,
      amount_out: parseFloat(e.amount) || 0,
      pay_category: e.pay_category || null,
    });
  }
  events.sort((a, b) => {
    const da = new Date(a.docdate).getTime();
    const dbb = new Date(b.docdate).getTime();
    if (da !== dbb) return da - dbb;
    return (a.docno || '').localeCompare(b.docno || '');
  });

  // running balance per pocket
  const running = { ...opening };
  const monthly = {};

  function bumpMonthly(dt, sign, amt, pocket) {
    const m = new Date(dt);
    if (Number.isNaN(m.getTime())) return;
    const key = `${m.getFullYear()}-${String(m.getMonth() + 1).padStart(2, '0')}`;
    monthly[key] ??= { in: 0, out: 0, by_pocket: { [POCKET_CASH]: 0, [POCKET_BANK]: 0, [POCKET_AGENCY]: 0 } };
    if (sign > 0) monthly[key].in += amt;
    else monthly[key].out += amt;
    monthly[key].by_pocket[pocket] += sign > 0 ? amt : -amt;
  }

  const lines = events.map((ev) => {
    if (ev.amount_in > 0) running[ev.pocket] += ev.amount_in;
    if (ev.amount_out > 0) running[ev.pocket] -= ev.amount_out;
    bumpMonthly(ev.docdate, ev.amount_in > 0 ? 1 : -1, ev.amount_in || ev.amount_out, ev.pocket);
    return {
      ...ev,
      balance_cash: running[POCKET_CASH],
      balance_bank: running[POCKET_BANK],
      balance_agency: running[POCKET_AGENCY],
    };
  });

  // monthly summary array — ต.ค. ของปี-1 ถึง ก.ย. ของปี
  const adYear = parseInt(buddhistYear, 10) - 543;
  const months = [];
  for (let i = 0; i < 12; i += 1) {
    const m = (10 + i - 1) % 12;
    const y = i < 3 ? adYear - 1 : adYear;
    const key = `${y}-${String(m + 1).padStart(2, '0')}`;
    const rec = monthly[key] || { in: 0, out: 0, by_pocket: { [POCKET_CASH]: 0, [POCKET_BANK]: 0, [POCKET_AGENCY]: 0 } };
    months.push({
      label: `${THAI_MONTH_NAMES[m]} ${(y + 543).toString().slice(-2)}`,
      year_be: y + 543,
      month_index: m + 1,
      total_in: rec.in,
      total_out: rec.out,
      cash: rec.by_pocket[POCKET_CASH],
      bank: rec.by_pocket[POCKET_BANK],
      agency: rec.by_pocket[POCKET_AGENCY],
    });
  }

  const totalIn = lines.reduce((s, l) => s + (l.amount_in || 0), 0);
  const totalOut = lines.reduce((s, l) => s + (l.amount_out || 0), 0);

  return {
    data: {
      fiscal_year: buddhistYear,
      category: { id: incomeType.id, code: incomeType.code, name: incomeType.name },
      opening,
      lines,
      months,
      total_in: totalIn,
      total_out: totalOut,
      ending: { ...running },
    },
  };
}

/**
 * รายการหมวดเงินนอกงบประมาณ (ใช้ feed dropdown)
 */
async function listOffBudgetCategories() {
  const rows = await db('incometype')
    .where('code', 'like', 'OB-%')
    .where('use', 'Y')
    .orderBy('sort', 'asc')
    .select('id', 'code', 'name');
  return { data: rows };
}

module.exports = {
  getOffBudgetLedger,
  listOffBudgetCategories,
  classifyPocket,
  POCKET_CASH,
  POCKET_BANK,
  POCKET_AGENCY,
};
