const db = require('../../configs/db.config');
const { classifyPocket, POCKET_CASH, POCKET_BANK, POCKET_AGENCY } =
  require('../../sacc_register/services/offbudget_register.service');
const { getCurrentFiscalYearBuddhist } = require('../../utils/fiscal_year.util');
const fiscalOpeningSvc = require('../../sacc_fiscal_year_opening/services/fiscal_year_opening.service');
const { EXPENSE_DOC_TS_SQL } = require('../../utils/expense_doc_timestamp');

/** map pocket key (in fiscal_year_opening) → POCKET_* */
const POCKET_LOOKUP = {
  cash: POCKET_CASH,
  bank: POCKET_BANK,
  agency: POCKET_AGENCY,
};

/** เพิ่มยอดยกมาเข้า pockets ของ bucket ตาม opening map ที่ดึงจากตาราง */
function addOpeningToPockets(pockets, openingForBucket) {
  if (!openingForBucket) return pockets;
  const out = { [POCKET_CASH]: pockets[POCKET_CASH], [POCKET_BANK]: pockets[POCKET_BANK], [POCKET_AGENCY]: pockets[POCKET_AGENCY] };
  for (const [pk, mapped] of Object.entries(POCKET_LOOKUP)) {
    out[mapped] = (out[mapped] || 0) + (parseFloat(openingForBucket[pk]) || 0);
  }
  return out;
}

function parseFiscalYearRange(fiscalYear) {
  const fy = fiscalYear ? parseInt(fiscalYear, 10) : null;
  if (!fy) return null;
  const adYear = fy - 543;
  return {
    start: `${adYear - 1}-10-01`,
    end: `${adYear}-09-30 23:59:59`,
  };
}

function fiscalYearOfDate(dateIsoString) {
  const d = new Date(dateIsoString);
  if (Number.isNaN(d.getTime())) return getCurrentFiscalYearBuddhist();
  const month = d.getMonth() + 1;
  const ad = d.getFullYear();
  return month >= 10 ? ad + 544 : ad + 543;
}

function httpError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

function parseReportDate(raw) {
  const date = (raw || new Date().toISOString().slice(0, 10)).toString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw httpError(400, 'รูปแบบวันที่ต้องเป็น YYYY-MM-DD');
  }
  const parsed = new Date(`${date}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) {
    throw httpError(400, 'วันที่ไม่ถูกต้อง');
  }
  return date;
}

function dayRange(date) {
  return {
    start: date,
    end: `${date} 23:59:59`,
  };
}

function parseReportFiscalYear(raw) {
  const fy = Number.parseInt(raw, 10) || getCurrentFiscalYearBuddhist();
  if (!Number.isInteger(fy) || fy < 2500 || fy > 2700) {
    throw httpError(400, 'ปีงบประมาณต้องเป็นปี พ.ศ. 2500-2700');
  }
  return fy;
}

function expenseReportGroupForCode(code) {
  const c = String(code || '').padStart(2, '0');
  if (c === '00') return { code: 'personnel', type_name: 'งบบุคลากร', sort: 1 };
  if (['01', '02', '03', '04'].includes(c)) return { code: 'operating', type_name: 'งบดำเนินงาน', sort: 2 };
  if (['05', '06'].includes(c)) return { code: 'investment', type_name: 'งบลงทุน', sort: 3 };
  if (c === '07') return { code: 'subsidy', type_name: 'งบเงินอุดหนุน', sort: 4 };
  return { code: 'other', type_name: 'อื่น ๆ', sort: 5 };
}

function groupExpenseRowsByOfficialSection(rows) {
  const groups = new Map();
  for (const raw of rows || []) {
    const meta = expenseReportGroupForCode(raw.code);
    const current = groups.get(meta.code) || {
      code: meta.code,
      type_name: meta.type_name,
      total: 0,
      count: 0,
      sort: meta.sort,
      lines: [],
    };
    current.total += parseFloat(raw.total) || 0;
    current.count += parseInt(raw.count, 10) || 0;
    current.lines.push(raw);
    groups.set(meta.code, current);
  }
  return Array.from(groups.values())
    .sort((a, b) => a.sort - b.sort)
    .map(({ sort, ...row }) => row);
}

/** moneygroup.id จาก seed — ห้ามสลับลำดับ */
const MG_STATE = 1;
const MG_OFF = 2;
const MG_TAX = 3;
const MG_GUARANTEE = 4;
const MG_BUDGET = 5;

function emptyPockets() {
  return { [POCKET_CASH]: 0, [POCKET_BANK]: 0, [POCKET_AGENCY]: 0 };
}

function mergeGroupedInOut(inRows, outRows) {
  const pockets = emptyPockets();
  for (const r of inRows) pockets[classifyPocket(r.mt_name)] += parseFloat(r.total) || 0;
  for (const r of outRows) pockets[classifyPocket(r.mt_name)] -= parseFloat(r.total) || 0;
  return pockets;
}

/** ลบยอด pocket ตามคีย์ POCKET_* (ใช้แถวแผ่นดินสุทธิ = mg1 − OB-12) */
function subtractPockets(a, b) {
  const out = emptyPockets();
  for (const k of [POCKET_CASH, POCKET_BANK, POCKET_AGENCY]) {
    out[k] = (a[k] || 0) - (b[k] || 0);
  }
  return out;
}

async function sumIncomeByMoneyType(dateEnd, whereFn) {
  const q = db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .leftJoin('budgetsource as bs', 'i.refbudgetsource', 'bs.id')
    .leftJoin('incometype as it', 'isub.refincometype', 'it.id')
    .where('i.docdate', '<=', dateEnd);
  if (whereFn) whereFn(q);
  return q
    .select('mt.name as mt_name', db.raw('COALESCE(SUM(isub.amount),0) as total'))
    .groupBy('mt.name');
}

async function sumExpenseByMoneyType(dateEnd, whereFn) {
  const q = db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .leftJoin('budgetsource as bs', 'e.refbudgetsource', 'bs.id')
    .leftJoin('incometype as it', 'es.refincometype', 'it.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} <= ?`, [dateEnd]);
  if (whereFn) whereFn(q);
  return q
    .select('mt.name as mt_name', db.raw('COALESCE(SUM(es.amount),0) as total'))
    .groupBy('mt.name');
}

async function netPocketsForBucket(dateEnd, whereIncome, whereExpense) {
  const [inRows, outRows] = await Promise.all([
    sumIncomeByMoneyType(dateEnd, whereIncome),
    sumExpenseByMoneyType(dateEnd, whereExpense),
  ]);
  return mergeGroupedInOut(inRows, outRows);
}

function pocketsToRow(key, label, remark, pockets, subRows) {
  const cash = pockets[POCKET_CASH];
  const bank = pockets[POCKET_BANK];
  const agency = pockets[POCKET_AGENCY];
  return {
    key,
    label,
    remark: remark || '',
    cash,
    bank,
    agency,
    total: cash + bank + agency,
    sub_rows: subRows && subRows.length ? subRows : undefined,
  };
}

function whereBudgetIncome(q) {
  q.where(function () {
    this.where('bs.refmoneygroup', MG_BUDGET).orWhere(function () {
      this.whereNotNull('i.refbudgetsource')
        .whereNull('bs.refmoneygroup')
        .where('bs.budget_type', 'งปม');
    });
  });
}
function whereBudgetExpense(q) {
  q.where(function () {
    this.where('bs.refmoneygroup', MG_BUDGET).orWhere(function () {
      this.whereNotNull('e.refbudgetsource')
        .whereNull('bs.refmoneygroup')
        .where('bs.budget_type', 'งปม');
    });
  });
}

function whereStateIncome(q) {
  q.where('bs.refmoneygroup', MG_STATE);
}
function whereStateExpense(q) {
  q.where('bs.refmoneygroup', MG_STATE);
}

function whereOb12Income(q) {
  q.where('bs.refmoneygroup', MG_OFF)
    .where('it.code', 'OB-12')
    .where(function () {
      this.whereNull('bs.budget_type').orWhereNot('bs.budget_type', 'รายได้สถานศึกษา');
    });
}
function whereOb12Expense(q) {
  q.where('bs.refmoneygroup', MG_OFF)
    .where('it.code', 'OB-12')
    .where(function () {
      this.whereNull('bs.budget_type').orWhereNot('bs.budget_type', 'รายได้สถานศึกษา');
    });
}

function whereOffbudgetIncome(q) {
  q.where(function () {
    this.where(function () {
      this.where('bs.refmoneygroup', MG_OFF)
        .where(function () {
          this.whereNull('bs.budget_type').orWhereNot('bs.budget_type', 'รายได้สถานศึกษา');
        })
        .where(function () {
          this.whereNull('it.code').orWhereNotIn('it.code', ['OB-01', 'OB-02', 'OB-12']);
        });
    })
      .orWhereNull('i.refbudgetsource')
      .orWhere(function () {
        this.whereNull('bs.refmoneygroup')
          .where('bs.budget_type', 'นอกงปม')
          .where(function () {
            this.whereNull('it.code').orWhereNotIn('it.code', ['OB-01', 'OB-02', 'OB-12']);
          });
      })
      .orWhere(function () {
        this.whereNull('bs.refmoneygroup')
          .whereIn('bs.budget_type', ['อุดหนุนทั่วไป', 'อุดหนุนเฉพาะกิจ'])
          .where(function () {
            this.whereNull('it.code').orWhereNotIn('it.code', ['OB-01', 'OB-02']);
          });
      });
  });
}
function whereOffbudgetExpense(q) {
  q.where(function () {
    this.where(function () {
      this.where('bs.refmoneygroup', MG_OFF)
        .where(function () {
          this.whereNull('bs.budget_type').orWhereNot('bs.budget_type', 'รายได้สถานศึกษา');
        })
        .where(function () {
          this.whereNull('it.code').orWhereNotIn('it.code', ['OB-01', 'OB-02', 'OB-12']);
        });
    })
      .orWhereNull('e.refbudgetsource')
      .orWhere(function () {
        this.whereNull('bs.refmoneygroup')
          .where('bs.budget_type', 'นอกงปม')
          .where(function () {
            this.whereNull('it.code').orWhereNotIn('it.code', ['OB-01', 'OB-02', 'OB-12']);
          });
      })
      .orWhere(function () {
        this.whereNull('bs.refmoneygroup')
          .whereIn('bs.budget_type', ['อุดหนุนทั่วไป', 'อุดหนุนเฉพาะกิจ'])
          .where(function () {
            this.whereNull('it.code').orWhereNotIn('it.code', ['OB-01', 'OB-02']);
          });
      });
  });
}

function whereGeneralSubsidyIncome(q) {
  q.where(function () {
    this.where(function () {
      this.where('bs.refmoneygroup', MG_OFF)
        .whereIn('it.code', ['OB-01', 'OB-02'])
        .where(function () {
          this.whereNull('bs.budget_type').orWhereNot('bs.budget_type', 'รายได้สถานศึกษา');
        });
    }).orWhere(function () {
      this.whereNull('bs.refmoneygroup')
        .whereIn('bs.budget_type', ['อุดหนุนทั่วไป', 'อุดหนุนเฉพาะกิจ'])
        .whereIn('it.code', ['OB-01', 'OB-02']);
    });
  });
}
function whereGeneralSubsidyExpense(q) {
  q.where(function () {
    this.where(function () {
      this.where('bs.refmoneygroup', MG_OFF)
        .whereIn('it.code', ['OB-01', 'OB-02'])
        .where(function () {
          this.whereNull('bs.budget_type').orWhereNot('bs.budget_type', 'รายได้สถานศึกษา');
        });
    }).orWhere(function () {
      this.whereNull('bs.refmoneygroup')
        .whereIn('bs.budget_type', ['อุดหนุนทั่วไป', 'อุดหนุนเฉพาะกิจ'])
        .whereIn('it.code', ['OB-01', 'OB-02']);
    });
  });
}

function whereSchoolIncome(q) {
  q.where('bs.budget_type', 'รายได้สถานศึกษา').where(function () {
    this.whereNull('bs.refmoneygroup').orWhereNotIn('bs.refmoneygroup', [
      MG_STATE,
      MG_TAX,
      MG_GUARANTEE,
      MG_BUDGET,
    ]);
  });
}
function whereSchoolExpense(q) {
  q.where('bs.budget_type', 'รายได้สถานศึกษา').where(function () {
    this.whereNull('bs.refmoneygroup').orWhereNotIn('bs.refmoneygroup', [
      MG_STATE,
      MG_TAX,
      MG_GUARANTEE,
      MG_BUDGET,
    ]);
  });
}

function whereTaxIncome(q) {
  q.where('bs.refmoneygroup', MG_TAX);
}
function whereTaxExpense(q) {
  q.where('bs.refmoneygroup', MG_TAX);
}

function whereGuaranteeIncome(q) {
  q.where('bs.refmoneygroup', MG_GUARANTEE);
}
function whereGuaranteeExpense(q) {
  q.where('bs.refmoneygroup', MG_GUARANTEE);
}

/**
 * รายงานเงินคงเหลือประจำวัน (Daily Cash Balance) — คู่มือหน้า 34
 *
 * แยก 7 แถวตามคู่มือ + คอลัมน์ เงินสด / ฝากธนาคาร / สปช. / รวม / หมายเหตุ
 * จำแนกจาก budgetsource.refmoneygroup (fallback budget_type / incometype.code)
 *
 * ยอด = ผลรวมรับ − ผลรวมจ่าย ตาม moneytype → classifyPocket
 * opening_balance ธนาคารรวมเข้า pocket ธนาคารของยอดรวม (ไม่แยกต่อแถว)
 */
async function getDailyBalance(query = {}) {
  const date = parseReportDate(query.date);
  const dateEnd = `${date} 23:59:59`;

  const [
    budgetP,
    stateP,
    ob12P,
    offP,
    genP,
    genPerHeadP,
    genPoorP,
    schoolP,
    schoolDonationP,
    schoolOtherP,
    taxP,
    guarP,
  ] = await Promise.all([
    netPocketsForBucket(dateEnd, whereBudgetIncome, whereBudgetExpense),
    netPocketsForBucket(dateEnd, whereStateIncome, whereStateExpense),
    netPocketsForBucket(dateEnd, whereOb12Income, whereOb12Expense),
    netPocketsForBucket(dateEnd, whereOffbudgetIncome, whereOffbudgetExpense),
    netPocketsForBucket(dateEnd, whereGeneralSubsidyIncome, whereGeneralSubsidyExpense),
    netPocketsForBucket(
      dateEnd,
      (q) => q.where('it.code', 'OB-01'),
      (q) => q.where('it.code', 'OB-01'),
    ),
    netPocketsForBucket(
      dateEnd,
      (q) => q.where('it.code', 'OB-02'),
      (q) => q.where('it.code', 'OB-02'),
    ),
    netPocketsForBucket(dateEnd, whereSchoolIncome, whereSchoolExpense),
    netPocketsForBucket(
      dateEnd,
      (q) => {
        whereSchoolIncome(q);
        q.where(function () {
          this.where('it.code', '06').orWhereRaw("it.name LIKE '%บริจาค%'");
        });
      },
      (q) => {
        whereSchoolExpense(q);
        q.where(function () {
          this.where('it.code', '06').orWhereRaw("it.name LIKE '%บริจาค%'");
        });
      },
    ),
    netPocketsForBucket(
      dateEnd,
      (q) => {
        whereSchoolIncome(q);
        q.where(function () {
          this.whereNull('it.code')
            .orWhereNot('it.code', '06')
            .whereRaw("(it.name IS NULL OR it.name NOT LIKE '%บริจาค%')");
        });
      },
      (q) => {
        whereSchoolExpense(q);
        q.where(function () {
          this.whereNull('it.code')
            .orWhereNot('it.code', '06')
            .whereRaw("(it.name IS NULL OR it.name NOT LIKE '%บริจาค%')");
        });
      },
    ),
    netPocketsForBucket(dateEnd, whereTaxIncome, whereTaxExpense),
    netPocketsForBucket(dateEnd, whereGuaranteeIncome, whereGuaranteeExpense),
  ]);

  // ดึงยอดยกมาของปีงบประมาณตามวันที่ขอ — ใช้เสริมในแต่ละ bucket × pocket
  const fyOfDate = fiscalYearOfDate(date);
  let openingMap = {};
  try {
    openingMap = await fiscalOpeningSvc.getMapForFiscalYear(fyOfDate);
  } catch (_) {
    openingMap = {};
  }

  const budgetPWithOpening = addOpeningToPockets(budgetP, openingMap.budget);
  const offPWithOpening = addOpeningToPockets(offP, openingMap.offbudget);
  const genPWithOpening = addOpeningToPockets(genP, openingMap.general_subsidy);
  const schoolPWithOpening = addOpeningToPockets(schoolP, openingMap.school_revenue);
  const taxPWithOpening = addOpeningToPockets(taxP, openingMap.withholding_tax);
  const guarPWithOpening = addOpeningToPockets(guarP, openingMap.contract_deposit);
  // state_revenue net = state − OB-12, แล้วบวก opening ของ state_revenue
  const stateNetP = subtractPockets(stateP, ob12P);
  const stateNetWithOpening = addOpeningToPockets(stateNetP, openingMap.state_revenue);

  const ob12Sub = pocketsToRow(
    'ob12',
    'ดอกเบี้ยบัญชีเงินอุดหนุนอื่น (OB-12)',
    'ยอด OB-12 ที่แสดงหักจากแถวแผ่นดินในตารางคู่มือหน้า 34',
    ob12P,
    null,
  );

  const rows = [
    pocketsToRow('budget', 'เงินงบประมาณ', '', budgetPWithOpening, null),
    pocketsToRow(
      'state_revenue',
      'เงินรายได้แผ่นดิน',
      'สุทธิ = เงินรายได้แผ่นดิน (mg=1) − OB-12; แถวย่อยแสดง OB-12',
      stateNetWithOpening,
      [ob12Sub],
    ),
    pocketsToRow('offbudget', 'เงินนอกงบประมาณ', '', offPWithOpening, null),
    pocketsToRow(
      'general_subsidy',
      'เงินอุดหนุนทั่วไป',
      'หมวด OB-01 (รายหัว) / OB-02 (ปัจจัยพื้นฐาน)',
      genPWithOpening,
      [
        pocketsToRow('general_subsidy_per_head', 'ค่าจัดการเรียนการสอน (OB-01)', '', genPerHeadP, null),
        pocketsToRow('general_subsidy_poor', 'ปัจจัยพื้นฐานนักเรียนยากจน (OB-02)', '', genPoorP, null),
      ],
    ),
    pocketsToRow(
      'school_revenue',
      'เงินรายได้สถานศึกษา',
      'แยกตาม budget_type รายได้สถานศึกษา',
      schoolPWithOpening,
      [
        pocketsToRow('school_revenue_donation', 'เงินบริจาค', '', schoolDonationP, null),
        pocketsToRow('school_revenue_other', 'รายได้สถานศึกษาอื่น', '', schoolOtherP, null),
      ],
    ),
    pocketsToRow('withholding_tax', 'เงินภาษีหัก ณ ที่จ่าย', '', taxPWithOpening, null),
    pocketsToRow('contract_deposit', 'เงินประกันสัญญา', '', guarPWithOpening, null),
  ];

  let bankOpening = 0;
  try {
    const r = await db('bankaccount').sum('opening_balance as t').first();
    bankOpening = parseFloat(r?.t) || 0;
  } catch (_) {}

  let bankBreakdown = [];
  try {
    bankBreakdown = await db('bankaccount as ba')
      .leftJoin('bank as b', 'ba.refbank', 'b.id')
      .select(
        'ba.id', 'ba.accountnumber', 'ba.opening_balance',
        'b.name as bank_name',
      )
      .orderBy('ba.id', 'asc');
  } catch (_) {}

  // sumRows สรุปเฉพาะแถวหลัก เพราะ sub_rows เป็นคำอธิบาย/แตกย่อยของแถวหลัก
  const sumRows = rows.reduce((acc, r) => {
    acc.cash += r.cash;
    acc.bank += r.bank;
    acc.agency += r.agency;
    acc.total += r.total;
    return acc;
  }, { cash: 0, bank: 0, agency: 0, total: 0 });

  // หาก fiscal_year_opening ของ bank ยังไม่ถูกตั้งเลย ให้ fallback ไป bankaccount.opening_balance
  const hasOpeningRows = Object.values(openingMap).some(
    (b) => b && (b.cash !== 0 || b.bank !== 0 || b.agency !== 0),
  );
  const bankFallback = hasOpeningRows ? 0 : bankOpening;

  const pocketsGrand = {
    [POCKET_CASH]: sumRows.cash,
    [POCKET_BANK]: sumRows.bank + bankFallback,
    [POCKET_AGENCY]: sumRows.agency,
  };
  const totalAll = pocketsGrand[POCKET_CASH] + pocketsGrand[POCKET_BANK] + pocketsGrand[POCKET_AGENCY];

  // ใช้ปีงบของวันที่ที่ขอ (ไม่ใช่ปีปัจจุบัน) เพื่อให้รายงานย้อนหลังถูกต้อง
  const fyForLimit = String(fyOfDate);
  const limits = await db('cash_keeping_limit')
    .where('fiscal_year', fyForLimit)
    .where('use', 'Y');

  const generalLimit = limits.find((x) => x.fund_kind === 'general' && x.school_size === 'small');
  const cashOverLimit =
    generalLimit && pocketsGrand[POCKET_CASH] > parseFloat(generalLimit.cash_max);

  return {
    data: {
      date,
      fiscal_year: fyOfDate,
      rows,
      bank_opening_total: bankOpening,
      opening_source: hasOpeningRows ? 'fiscal_year_opening' : 'bankaccount_only',
      cash: pocketsGrand[POCKET_CASH],
      bank: pocketsGrand[POCKET_BANK],
      agency: pocketsGrand[POCKET_AGENCY],
      total: totalAll,
      bank_breakdown: bankBreakdown,
      keeping_limits: limits,
      cash_over_limit: !!cashOverLimit,
      cash_limit_used: generalLimit ? parseFloat(generalLimit.cash_max) : null,
    },
  };
}

/**
 * งบเทียบยอดเงินฝากธนาคาร (Bank Reconciliation) — คู่มือหน้า 32
 *
 * อิง bankaccount + paycheque (เช็คที่ออกแล้วยังไม่ขึ้นเงิน)
 * แสดง:
 *   - ยอดสมุดเงินฝาก = opening_balance + รับเข้าผ่าน bank moneytype − จ่ายผ่าน bank
 *   - ยอด Statement = ยอดสมุด + เช็คที่ยังไม่เคลียร์
 *
 * รับ–จ่ายผ่านธนาคารแยกตามบัญชี — อ่านจาก view
 *   `v_report_income_bank_movement` / `v_report_expense_bank_movement` (คอลัมน์ effective_refbankaccount)
 * รายการที่ resolve ไม่ได้รวมใน `unallocated_bank_movements`
 */
async function getBankReconciliation(query = {}) {
  const asOf = parseReportDate(query.date);
  const asOfEnd = `${asOf} 23:59:59`;

  let accounts = [];
  try {
    accounts = await db('bankaccount as ba')
      .leftJoin('bank as b', 'ba.refbank', 'b.id')
      .select(
        'ba.id', 'ba.accountnumber', 'ba.opening_balance',
        'b.name as bank_name',
      )
      .orderBy('ba.id', 'asc');
  } catch (_) {
    return { data: { error: 'ไม่พบตาราง bankaccount' } };
  }

  let chequeMap = {};
  try {
    const rows = await db('paycheque as p')
      .leftJoin('expense as e', 'p.refexpense', 'e.id')
      .whereRaw(`${EXPENSE_DOC_TS_SQL} <= ?`, [asOfEnd])
      .whereNull('p.cleared_at')
      .select('p.refchequeaccount', db.raw('SUM(p.chequeamount) as t'))
      .groupBy('p.refchequeaccount');
    for (const r of rows) {
      if (r.refchequeaccount != null) {
        chequeMap[r.refchequeaccount] = parseFloat(r.t) || 0;
      }
    }
  } catch (_) {}

  const bankIncomeWhere = (qb) => {
    qb.where(function () {
      this.whereRaw("LOWER(mt.name) LIKE ?", ['%ฝาก%'])
        .orWhereRaw("LOWER(mt.name) LIKE ?", ['%bank%'])
        .orWhereRaw("LOWER(mt.name) LIKE ?", ['%โอน%']);
    });
  };
  const bankExpenseWhere = (qb) => {
    qb.where(function () {
      this.whereRaw("LOWER(mt.name) LIKE ?", ['%ฝาก%'])
        .orWhereRaw("LOWER(mt.name) LIKE ?", ['%bank%'])
        .orWhereRaw("LOWER(mt.name) LIKE ?", ['%เช็ค%']);
    });
  };

  const inRows = await db('v_report_income_bank_movement as v')
    .join('moneytype as mt', 'v.refmoneytype', 'mt.id')
    .where('v.docdate', '<=', asOfEnd)
    .modify(bankIncomeWhere)
    .sum('v.amount as t').first();

  const outRows = await db('v_report_expense_bank_movement as v')
    .join('moneytype as mt', 'v.refmoneytype', 'mt.id')
    .whereRaw('v.doc_ts <= ?', [asOfEnd])
    .modify(bankExpenseWhere)
    .sum('v.amount as t').first();

  const totalIn = parseFloat(inRows?.t) || 0;
  const totalOut = parseFloat(outRows?.t) || 0;

  let inByAccount = [];
  let outByAccount = [];
  try {
    inByAccount = await db('v_report_income_bank_movement as v')
      .join('moneytype as mt', 'v.refmoneytype', 'mt.id')
      .where('v.docdate', '<=', asOfEnd)
      .modify(bankIncomeWhere)
      .select(
        'v.effective_refbankaccount as bank_slot',
        db.raw('COALESCE(SUM(v.amount),0) as t'),
      )
      .groupBy('v.effective_refbankaccount');
    outByAccount = await db('v_report_expense_bank_movement as v')
      .join('moneytype as mt', 'v.refmoneytype', 'mt.id')
      .whereRaw('v.doc_ts <= ?', [asOfEnd])
      .modify(bankExpenseWhere)
      .select(
        'v.effective_refbankaccount as bank_slot',
        db.raw('COALESCE(SUM(v.amount),0) as t'),
      )
      .groupBy('v.effective_refbankaccount');
  } catch (_) {
    inByAccount = [];
    outByAccount = [];
  }

  const inMap = {};
  for (const r of inByAccount) {
    const slot = r.bank_slot;
    const k = slot == null ? '__null__' : String(slot);
    inMap[k] = (inMap[k] || 0) + (parseFloat(r.t) || 0);
  }
  const outMap = {};
  for (const r of outByAccount) {
    const slot = r.bank_slot;
    const k = slot == null ? '__null__' : String(slot);
    outMap[k] = (outMap[k] || 0) + (parseFloat(r.t) || 0);
  }

  const accountsOut = accounts.map((a) => {
    const idStr = String(a.id);
    const tin = inMap[idStr] || 0;
    const tout = outMap[idStr] || 0;
    const opening = parseFloat(a.opening_balance) || 0;
    return {
      ...a,
      total_in_bank: tin,
      total_out_bank: tout,
      book_balance: opening + tin - tout,
    };
  });

  const uIn = inMap.__null__ || 0;
  const uOut = outMap.__null__ || 0;
  const unallocated = {
    total_in_bank: uIn,
    total_out_bank: uOut,
    /** ไม่รวมยอดเปิดบัญชี — เฉพาะ movement ที่ยังไม่ระบุเลขบัญชี */
    net_movement: uIn - uOut,
  };

  const totalOpening = accounts.reduce((s, a) => s + (parseFloat(a.opening_balance) || 0), 0);
  const bookBalance = totalOpening + totalIn - totalOut;
  const totalCheque = Object.values(chequeMap).reduce((s, v) => s + v, 0);
  let adjustmentNotes = [];
  try {
    adjustmentNotes = await db('bank_reconciliation_adjustment')
      .where('as_of_date', asOf)
      .orderBy('id', 'desc');
  } catch (_) {}

  return {
    data: {
      as_of: asOf,
      accounts: accountsOut,
      unallocated_bank_movements: unallocated,
      total_opening: totalOpening,
      total_in_bank: totalIn,
      total_out_bank: totalOut,
      book_balance: bookBalance,
      outstanding_cheque_total: totalCheque,
      reconciled_statement_balance: bookBalance + totalCheque,
      adjustment_policy: 'notes_only',
      adjustment_notes: adjustmentNotes,
    },
  };
}

/**
 * รายงานรับ-จ่ายเงินรายได้สถานศึกษา ประจำปีงบประมาณ
 * (Annual School Revenue/Expense Summary) — คู่มือหน้า 33
 */
async function getAnnualSummary(query = {}) {
  const fy = parseReportFiscalYear(query.fiscal_year);
  const adYear = fy - 543;
  const startDate = `${adYear - 1}-10-01`;
  const endDate = `${adYear}-09-30 23:59:59`;

  const incomeByType = await db('income as i')
    .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('incometype as it', 'isub.refincometype', 'it.id')
    .whereBetween('i.docdate', [startDate, endDate])
    .select(
      'it.id', 'it.code', 'it.name as type_name',
      db.raw('COALESCE(SUM(isub.amount),0) as total'),
      db.raw('COUNT(DISTINCT i.id) as count'),
    )
    .groupBy('it.id', 'it.code', 'it.name')
    .orderBy('it.sort', 'asc');

  const expenseByType = await db('expense as e')
    .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('expensetype as et', 'es.refexpensetype', 'et.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} BETWEEN ? AND ?`, [startDate, endDate])
    .select(
      'et.id', 'et.code', 'et.name as type_name',
      db.raw('COALESCE(SUM(es.amount),0) as total'),
      db.raw('COUNT(DISTINCT e.id) as count'),
    )
    .groupBy('et.id', 'et.code', 'et.name')
    .orderBy('et.sort', 'asc');

  const totalIncome = incomeByType.reduce((s, r) => s + (parseFloat(r.total) || 0), 0);
  const totalExpense = expenseByType.reduce((s, r) => s + (parseFloat(r.total) || 0), 0);
  const expenseGroups = groupExpenseRowsByOfficialSection(expenseByType);

  // ยอดยกมาต้นปีงบ — รวมเฉพาะ bucket ที่เกี่ยวข้องกับรายงานหน้า 33
  let openingTotal = 0;
  let openingMap = {};
  try {
    openingMap = await fiscalOpeningSvc.getMapForFiscalYear(fy);
    for (const bucket of Object.keys(openingMap)) {
      const b = openingMap[bucket] || {};
      openingTotal += (parseFloat(b.cash) || 0)
        + (parseFloat(b.bank) || 0)
        + (parseFloat(b.agency) || 0);
    }
  } catch (_) {}

  return {
    data: {
      fiscal_year: fy,
      income: incomeByType,
      expense: expenseGroups,
      expense_details: expenseByType,
      total_income: totalIncome,
      total_expense: totalExpense,
      balance: totalIncome - totalExpense,
      opening_total: openingTotal,
      opening_by_bucket: openingMap,
      ending_balance: openingTotal + (totalIncome - totalExpense),
    },
  };
}

/**
 * สรุปเงินสดรายวัน — สอดคล้องกับ `loadDailyCashSummaryLocal` ในแอป Flutter
 * query.date = YYYY-MM-DD
 */
async function getDailyCashSummary(query = {}) {
  const date = parseReportDate(query.date);
  const range = dayRange(date);

  function sumPocketRows(rows, pocket, incomeSign) {
    let s = 0;
    for (const r of rows) {
      if (classifyPocket(r.mt_name) !== pocket) continue;
      const amt = parseFloat(r.amount) || 0;
      s += incomeSign * amt;
    }
    return s;
  }

  const incBefore = await db('income as i')
    .join('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .where('i.docdate', '<', range.start)
    .select('isub.amount', 'mt.name as mt_name');

  const expBefore = await db('expense as e')
    .join('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} < ?`, [range.start])
    .select('es.amount', 'mt.name as mt_name');

  const opening =
    sumPocketRows(incBefore, POCKET_CASH, 1) + sumPocketRows(expBefore, POCKET_CASH, -1);

  const incDay = await db('income as i')
    .join('incomesub as isub', 'i.id', 'isub.refincome')
    .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
    .where('i.docdate', '>=', range.start)
    .where('i.docdate', '<=', range.end)
    .select('isub.amount', 'mt.name as mt_name');

  const expDay = await db('expense as e')
    .join('expensesub as es', 'e.id', 'es.refexpense')
    .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} >= ?`, [range.start])
    .whereRaw(`${EXPENSE_DOC_TS_SQL} <= ?`, [range.end])
    .select('es.amount', 'mt.name as mt_name');

  const receivedCash = sumPocketRows(incDay, POCKET_CASH, 1);
  const receivedTransfer = sumPocketRows(incDay, POCKET_BANK, 1);
  const paidCash = sumPocketRows(expDay, POCKET_CASH, 1);
  const closingCash = opening + receivedCash - paidCash;

  return {
    data: {
      date,
      opening_cash: opening,
      received_cash_today: receivedCash,
      received_transfer_today: receivedTransfer,
      paid_cash_today: paidCash,
      closing_cash: closingCash,
    },
  };
}

/**
 * รายงานเช็คค้างตัดบัญชี — คู่มือหน้า 32 (ส่วนหนึ่งของงบเทียบยอด)
 */
async function getOutstandingCheques(query = {}) {
  const asOf = parseReportDate(query.date);
  const asOfEnd = `${asOf} 23:59:59`;
  const fy = query.fiscal_year ? parseReportFiscalYear(query.fiscal_year) : null;
  const range = parseFiscalYearRange(fy);

  const builder = db('paycheque as p')
    .leftJoin('chequeaccount as ca', 'p.refchequeaccount', 'ca.id')
    .leftJoin('bank as b', 'ca.refbank', 'b.id')
    .leftJoin('expense as e', 'p.refexpense', 'e.id')
    .whereNull('p.cleared_at')
    .whereRaw(`${EXPENSE_DOC_TS_SQL} <= ?`, [asOfEnd])
    .select(
      'p.id as pay_cheque_id',
      'p.chequeno',
      'p.chequeamount',
      db.raw(`${EXPENSE_DOC_TS_SQL} as docdate`),
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
  const total = rows.reduce(
    (s, r) => s + (parseFloat(r.chequeamount) || 0),
    0,
  );

  return {
    data: {
      as_of: asOf,
      fiscal_year: fy,
      rows,
      total_outstanding: parseFloat(total.toFixed(2)),
      count: rows.length,
    },
  };
}

module.exports = {
  getDailyBalance,
  getBankReconciliation,
  getAnnualSummary,
  getDailyCashSummary,
  getOutstandingCheques,
  expenseReportGroupForCode,
  groupExpenseRowsByOfficialSection,
  parseReportDate,
  parseReportFiscalYear,
};
