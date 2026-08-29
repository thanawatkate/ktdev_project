const db = require('../../configs/db.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { writeAuditLog } = require('../../sacc_auditlog/auditlog.service');
const {
  classifyPocket,
  POCKET_CASH,
  POCKET_BANK,
  POCKET_AGENCY,
} = require('../../sacc_register/services/offbudget_register.service');
const {
  getCurrentFiscalYearBuddhist,
  fiscalYearRangeFromBuddhist,
} = require('../../utils/fiscal_year.util');
const { EXPENSE_DOC_TS_SQL } = require('../../utils/expense_doc_timestamp');

const TABLE = 'fiscal_year_opening';

const VALID_BUCKETS = [
  'budget',
  'state_revenue',
  'offbudget',
  'general_subsidy',
  'school_revenue',
  'withholding_tax',
  'contract_deposit',
];
const VALID_POCKETS = ['cash', 'bank', 'agency'];

const POCKET_KEY_MAP = {
  [POCKET_CASH]: 'cash',
  [POCKET_BANK]: 'bank',
  [POCKET_AGENCY]: 'agency',
};

function buildDefaultGrid(fiscalYear) {
  const rows = [];
  for (const bucket of VALID_BUCKETS) {
    for (const pocket of VALID_POCKETS) {
      rows.push({
        fiscal_year: String(fiscalYear),
        bucket,
        pocket,
        opening_amount: 0,
        remark: null,
        source: 'manual',
      });
    }
  }
  return rows;
}

/** ดึงยอดยกมาทั้งปี เป็น 2D map [bucket][pocket] = amount */
async function getMapForFiscalYear(fiscalYear) {
  if (!fiscalYear) return {};
  const rows = await db(TABLE)
    .where('fiscal_year', String(fiscalYear))
    .where('use', 'Y')
    .select('bucket', 'pocket', 'opening_amount');
  const map = {};
  for (const bucket of VALID_BUCKETS) {
    map[bucket] = { cash: 0, bank: 0, agency: 0 };
  }
  for (const r of rows) {
    if (!VALID_BUCKETS.includes(r.bucket)) continue;
    if (!VALID_POCKETS.includes(r.pocket)) continue;
    map[r.bucket][r.pocket] = parseFloat(r.opening_amount) || 0;
  }
  return map;
}

/** API: GET — list opening grid (7 buckets × 3 pockets) ของปีที่ขอ */
async function listGrid(query = {}) {
  const fy = String(
    query.fiscal_year || getCurrentFiscalYearBuddhist(),
  ).trim();
  if (!/^\d{4}$/.test(fy)) {
    return { status: 'error', message: 'fiscal_year ไม่ถูกต้อง' };
  }

  const rows = await db(TABLE)
    .where('fiscal_year', fy)
    .select('id', 'fiscal_year', 'bucket', 'pocket', 'opening_amount',
            'remark', 'source', 'use', 'created', 'updated');

  const byKey = new Map();
  for (const r of rows) byKey.set(`${r.bucket}::${r.pocket}`, r);

  const data = [];
  for (const bucket of VALID_BUCKETS) {
    for (const pocket of VALID_POCKETS) {
      const existing = byKey.get(`${bucket}::${pocket}`);
      data.push(existing || {
        id: null,
        fiscal_year: fy,
        bucket,
        pocket,
        opening_amount: 0,
        remark: null,
        source: 'manual',
        use: 'Y',
      });
    }
  }

  return { data: { fiscal_year: fy, rows: data } };
}

/** API: POST/PATCH — upsert ทั้ง grid ของปี */
async function upsertGrid(body, meta = {}) {
  if (!body.token) return { status: 'error', message: 'Token not found' };
  if (checkTokenEXP(body.token)) return { status: 'error', message: 'Token exp' };

  const fy = String(body.fiscal_year || '').trim();
  if (!/^\d{4}$/.test(fy)) {
    return { status: 'error', message: 'fiscal_year ไม่ถูกต้อง' };
  }
  const rows = Array.isArray(body.rows) ? body.rows : [];
  if (rows.length === 0) {
    return { status: 'error', message: 'ต้องระบุ rows อย่างน้อย 1 รายการ' };
  }

  // validate ทุกแถวก่อน เพื่อ atomic transaction
  const cleaned = [];
  for (const r of rows) {
    if (!VALID_BUCKETS.includes(r.bucket)) {
      return { status: 'error', message: `bucket ไม่ถูกต้อง: ${r.bucket}` };
    }
    if (!VALID_POCKETS.includes(r.pocket)) {
      return { status: 'error', message: `pocket ไม่ถูกต้อง: ${r.pocket}` };
    }
    const amount = parseFloat(r.opening_amount);
    if (!Number.isFinite(amount)) {
      return { status: 'error', message: 'opening_amount ต้องเป็นตัวเลข' };
    }
    cleaned.push({
      fiscal_year: fy,
      bucket: r.bucket,
      pocket: r.pocket,
      opening_amount: amount,
      remark: r.remark != null ? String(r.remark) : null,
      source: r.source || 'manual',
      use: 'Y',
      updated: new Date(),
    });
  }

  await db.transaction(async (trx) => {
    for (const row of cleaned) {
      const existing = await trx(TABLE)
        .where({ fiscal_year: row.fiscal_year, bucket: row.bucket, pocket: row.pocket })
        .first();
      if (existing) {
        await trx(TABLE).where('id', existing.id).update(row);
      } else {
        await trx(TABLE).insert({ ...row, created: new Date() });
      }
    }
  });

  await writeAuditLog({
    tablename: TABLE,
    record_id: null,
    action: 'UPSERT_GRID',
    new_data: JSON.stringify({ fiscal_year: fy, count: cleaned.length }),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  }).catch(() => {});

  return { status: 'successfully', message: 'บันทึกยอดยกมาสำเร็จ', fiscal_year: fy };
}

/**
 * คำนวณ "ยอดยกมาเสนอ" จากทรานแซคชันก่อน startDate ของปี
 * อ้างอิงนิยาม bucket จาก getDailyBalance() (extra_reports.service.js)
 *
 * คืน 2D map [bucket][pocket] = amount เพื่อ prefill หน้า UI
 */
async function computeSuggestedOpening(query = {}) {
  const fy = String(
    query.fiscal_year || getCurrentFiscalYearBuddhist(),
  ).trim();
  if (!/^\d{4}$/.test(fy)) {
    return { status: 'error', message: 'fiscal_year ไม่ถูกต้อง' };
  }
  const range = fiscalYearRangeFromBuddhist(fy);
  if (!range) return { status: 'error', message: 'fiscal_year ไม่ถูกต้อง' };
  // คำนวณยอดสะสมก่อน startDate (= ก่อน 1 ต.ค. ของ ปี-1)
  const cutoff = `${range.startDate} 00:00:00`;

  // moneygroup.id อ้างอิงตาม seed (ห้ามสลับ)
  const MG_STATE = 1;
  const MG_OFF = 2;
  const MG_TAX = 3;
  const MG_GUARANTEE = 4;
  const MG_BUDGET = 5;

  // helper: ดึง sum income/expense ก่อน cutoff แยก mt.name แล้ว classifyPocket
  async function sumIn(whereFn) {
    const q = db('income as i')
      .leftJoin('incomesub as isub', 'i.id', 'isub.refincome')
      .leftJoin('moneytype as mt', 'isub.refmoneytype', 'mt.id')
      .leftJoin('budgetsource as bs', 'i.refbudgetsource', 'bs.id')
      .leftJoin('incometype as it', 'isub.refincometype', 'it.id')
      .where('i.docdate', '<', cutoff);
    if (whereFn) whereFn(q);
    return q
      .select('mt.name as mt_name', db.raw('COALESCE(SUM(isub.amount),0) as total'))
      .groupBy('mt.name');
  }
  async function sumOut(whereFn) {
    const q = db('expense as e')
      .leftJoin('expensesub as es', 'e.id', 'es.refexpense')
      .leftJoin('moneytype as mt', 'es.refmoneytype', 'mt.id')
      .leftJoin('budgetsource as bs', 'e.refbudgetsource', 'bs.id')
      .leftJoin('incometype as it', 'es.refincometype', 'it.id')
      .whereRaw(`${EXPENSE_DOC_TS_SQL} < ?`, [cutoff]);
    if (whereFn) whereFn(q);
    return q
      .select('mt.name as mt_name', db.raw('COALESCE(SUM(es.amount),0) as total'))
      .groupBy('mt.name');
  }
  function classify(rows, target) {
    for (const r of rows) {
      const p = POCKET_KEY_MAP[classifyPocket(r.mt_name)] || 'cash';
      target[p] += parseFloat(r.total) || 0;
    }
  }
  async function netBucket(whereIn, whereOut) {
    const pockets = { cash: 0, bank: 0, agency: 0 };
    const [inRows, outRows] = await Promise.all([sumIn(whereIn), sumOut(whereOut)]);
    classify(inRows, pockets);
    const outAgg = { cash: 0, bank: 0, agency: 0 };
    classify(outRows, outAgg);
    pockets.cash -= outAgg.cash;
    pockets.bank -= outAgg.bank;
    pockets.agency -= outAgg.agency;
    return pockets;
  }

  // bucket: budget
  const budget = await netBucket(
    (q) => q.where('bs.refmoneygroup', MG_BUDGET),
    (q) => q.where('bs.refmoneygroup', MG_BUDGET),
  );

  // bucket: state_revenue = state − OB-12
  const state = await netBucket(
    (q) => q.where('bs.refmoneygroup', MG_STATE),
    (q) => q.where('bs.refmoneygroup', MG_STATE),
  );
  const ob12 = await netBucket(
    (q) => q.where('bs.refmoneygroup', MG_OFF).where('it.code', 'OB-12'),
    (q) => q.where('bs.refmoneygroup', MG_OFF).where('it.code', 'OB-12'),
  );
  const stateNet = {
    cash: state.cash - ob12.cash,
    bank: state.bank - ob12.bank,
    agency: state.agency - ob12.agency,
  };

  // bucket: offbudget (OB ที่ไม่ใช่ 01/02/12)
  const offbudget = await netBucket(
    (q) => q.where('bs.refmoneygroup', MG_OFF)
      .where((qb) => qb.whereNull('it.code').orWhereNotIn('it.code', ['OB-01', 'OB-02', 'OB-12'])),
    (q) => q.where('bs.refmoneygroup', MG_OFF)
      .where((qb) => qb.whereNull('it.code').orWhereNotIn('it.code', ['OB-01', 'OB-02', 'OB-12'])),
  );

  // bucket: general_subsidy (OB-01/OB-02)
  const general = await netBucket(
    (q) => q.where('bs.refmoneygroup', MG_OFF).whereIn('it.code', ['OB-01', 'OB-02']),
    (q) => q.where('bs.refmoneygroup', MG_OFF).whereIn('it.code', ['OB-01', 'OB-02']),
  );

  // bucket: school_revenue
  const school = await netBucket(
    (q) => q.where('bs.budget_type', 'รายได้สถานศึกษา'),
    (q) => q.where('bs.budget_type', 'รายได้สถานศึกษา'),
  );

  // bucket: withholding_tax
  const tax = await netBucket(
    (q) => q.where('bs.refmoneygroup', MG_TAX),
    (q) => q.where('bs.refmoneygroup', MG_TAX),
  );

  // bucket: contract_deposit
  const guarantee = await netBucket(
    (q) => q.where('bs.refmoneygroup', MG_GUARANTEE),
    (q) => q.where('bs.refmoneygroup', MG_GUARANTEE),
  );

  // bank opening เพิ่มเข้า budget/school bucket เป็นค่าเริ่มต้น
  let bankOpening = 0;
  try {
    const r = await db('bankaccount').sum('opening_balance as t').first();
    bankOpening = parseFloat(r?.t) || 0;
  } catch (_) {}

  const result = {
    fiscal_year: fy,
    rows: [],
    bank_opening_total: bankOpening,
  };
  const data = {
    budget,
    state_revenue: stateNet,
    offbudget,
    general_subsidy: general,
    school_revenue: school,
    withholding_tax: tax,
    contract_deposit: guarantee,
  };
  for (const bucket of VALID_BUCKETS) {
    for (const pocket of VALID_POCKETS) {
      result.rows.push({
        fiscal_year: fy,
        bucket,
        pocket,
        opening_amount: data[bucket][pocket],
        source: 'computed',
      });
    }
  }
  return { data: result };
}

/**
 * คัดลอกยอดปลายปี N → ยอดยกมาปี N+1
 * - fiscal_year = ปีปลายทาง (N+1)
 * - source: 'year_end_close'
 *
 * คำนวณ ending ของปี N โดยใช้ end-date = 30 ก.ย. ของปี (พ.ศ. N)
 * แล้ว INSERT/UPDATE row ของปี N+1 ตาม 7×3 grid เดียวกับ getDailyBalance
 */
async function copyFromPreviousYearEnding(body, meta = {}) {
  if (!body.token) return { status: 'error', message: 'Token not found' };
  if (checkTokenEXP(body.token)) return { status: 'error', message: 'Token exp' };

  const targetFy = String(body.fiscal_year || '').trim();
  if (!/^\d{4}$/.test(targetFy)) {
    return { status: 'error', message: 'fiscal_year ไม่ถูกต้อง' };
  }
  const targetFyNum = parseInt(targetFy, 10);
  const sourceFyNum = targetFyNum - 1;
  // คำนวณจาก getDailyBalance ณ วันที่ปิดงบของปี source
  const range = fiscalYearRangeFromBuddhist(sourceFyNum);
  if (!range) return { status: 'error', message: 'ไม่สามารถคำนวณปีก่อนได้' };
  const computed = await computeSuggestedOpening({ fiscal_year: targetFy });
  if (computed.status === 'error') return computed;

  // upsert
  const rows = computed.data.rows.map((r) => ({ ...r, source: 'year_end_close' }));
  return upsertGrid({
    token: body.token,
    fiscal_year: targetFy,
    rows,
  }, meta);
}

module.exports = {
  listGrid,
  upsertGrid,
  computeSuggestedOpening,
  copyFromPreviousYearEnding,
  getMapForFiscalYear,
  VALID_BUCKETS,
  VALID_POCKETS,
  buildDefaultGrid,
};
