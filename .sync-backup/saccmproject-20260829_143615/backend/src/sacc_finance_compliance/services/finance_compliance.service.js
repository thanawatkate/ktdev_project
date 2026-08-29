const db = require('../../configs/db.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { getDailyBalance } = require('../../sacc_reports/services/extra_reports.service');

const REASON_CODES = new Set([
  'outstanding_cheque',
  'transfer_pending',
  'deposit_pending',
  'fee_adjustment',
  'other',
]);

function parseDate(raw) {
  const s = (raw || new Date().toISOString()).toString().slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : new Date().toISOString().slice(0, 10);
}

function nextMonthStart(date) {
  const current = new Date(`${date.slice(0, 7)}-01T00:00:00Z`);
  current.setUTCMonth(current.getUTCMonth() + 1);
  return current.toISOString().slice(0, 10);
}

function businessDaysSince(startIso, endIso) {
  const start = new Date(startIso);
  const end = new Date(endIso);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0;
  let count = 0;
  const cur = new Date(start);
  cur.setDate(cur.getDate() + 1);
  while (cur <= end) {
    const dow = cur.getDay();
    if (dow !== 0 && dow !== 6) count += 1;
    cur.setDate(cur.getDate() + 1);
  }
  return count;
}

/**
 * แจ้งเตือนความเสี่ยงตามคู่มือ — รายได้แผ่นดิน / ภาษีหัก ณ ที่จ่าย / เงินยืม / ปิดวัน / วงเงินสด
 */
async function getComplianceAlerts(query = {}) {
  const today = parseDate(query.date);
  const alerts = [];

  // วันงานที่ยังไม่ปิด (ย้อนหลังไม่เกิน 7 วันทำการ)
  try {
    const weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 14);
    const from = weekAgo.toISOString().slice(0, 10);
    const closedRows = await db('daily_closing')
      .where('close_date', '>=', from)
      .where('close_date', '<', today)
      .select('close_date');
    const closedSet = new Set(closedRows.map((r) => String(r.close_date).slice(0, 10)));
    const check = new Date(from);
    const end = new Date(today);
    end.setDate(end.getDate() - 1);
    while (check <= end) {
      const iso = check.toISOString().slice(0, 10);
      const dow = check.getDay();
      if (dow !== 0 && dow !== 6 && !closedSet.has(iso)) {
        alerts.push({
          severity: 'warning',
          code: 'daily_closing_missing',
          title: 'ยังไม่ปิดวัน',
          message: `วันที่ ${iso} ยังไม่มีการปิดวันและบันทึกรายงานเงินคงเหลือ`,
          due_date: iso,
        });
      }
      check.setDate(check.getDate() + 1);
    }
  } catch (_) {}

  // เงินยืมค้าง / ใกล้ครบกำหนด
  try {
    const loans = await db('loan as l')
      .select(
        'l.id',
        'l.docno',
        'l.duedate',
        db.raw('(COALESCE(l.amount,0) + COALESCE(l.opening_outstanding,0)) as borrow'),
      );
    for (const row of loans) {
      const repaid = await db('repayloan as r')
        .where('r.refloan', row.id)
        .sum({ t: 'r.amount' })
        .first();
      const outstanding = (parseFloat(row.borrow) || 0) - (parseFloat(repaid?.t) || 0);
      if (outstanding < 0.01) continue;
      const due = row.duedate ? String(row.duedate).slice(0, 10) : null;
      if (!due) continue;
      const days = Math.floor(
        (new Date(due).getTime() - new Date(today).getTime()) / 86400000,
      );
      if (days < 0) {
        alerts.push({
          severity: 'critical',
          code: 'loan_overdue',
          title: 'เงินยืมเกินกำหนด',
          message: `สัญญา ${row.docno} ค้างส่งใช้ ${outstanding.toFixed(2)} บาท (เลยกำหนด ${-days} วัน)`,
          due_date: due,
        });
      } else if (days <= 7) {
        alerts.push({
          severity: 'warning',
          code: 'loan_due_soon',
          title: 'เงินยืมใกล้ครบกำหนด',
          message: `สัญญา ${row.docno} ค้าง ${outstanding.toFixed(2)} บาท — เหลือ ${days} วัน`,
          due_date: due,
        });
      }
    }
  } catch (_) {}

  // ภาษีหัก ณ ที่จ่าย / ประกันที่ต้องนำส่ง (holding เกิน 7 วันหลังสิ้นเดือน)
  try {
    const monthStart = today.slice(0, 8) + '01';
    const holding = await db('deposit_guarantee')
      .where('status', 'holding')
      .where('record_date', '<', monthStart)
      .count({ c: '*' })
      .first();
    const cnt = parseInt(holding?.c, 10) || 0;
    if (cnt > 0) {
      alerts.push({
        severity: 'warning',
        code: 'deposit_submit_due',
        title: 'เงินฝากที่ต้องนำส่ง',
        message: `มี ${cnt} รายการเงินประกัน/ภาษีหัก ณ ที่จ่ายที่ยังถืออยู่ — ตรวจสอบกำหนดนำส่งภายใน 7 วันหลังสิ้นเดือน`,
        due_date: today,
      });
    }
  } catch (_) {}

  // รายได้แผ่นดิน — เตือนถ้าเดือนนี้ยังไม่มีรายการนำส่ง (treasury)
  try {
    const monthStart = `${today.slice(0, 7)}-01`;
    const treasuryRows = await db('income')
      .where('money_domain', 'treasury_income')
      .where('docdate', '>=', monthStart)
      .where('docdate', '<', nextMonthStart(today))
      .count({ c: '*' })
      .first();
    const day = parseInt(today.slice(8, 10), 10);
    if ((parseInt(treasuryRows?.c, 10) || 0) === 0 && day >= 20) {
      alerts.push({
        severity: 'info',
        code: 'treasury_remit_reminder',
        title: 'รายได้แผ่นดิน',
        message: 'เดือนนี้ยังไม่พบรายการบันทึกนำส่งรายได้แผ่นดิน — ตรวจสอบตามรอบนำส่งประจำเดือน',
        due_date: today,
      });
    }
  } catch (_) {}

  // วงเงินสดเกิน (จากรายงานประจำวัน)
  try {
    const bal = await getDailyBalance({ date: today });
    if (bal?.data?.cash_over_limit) {
      alerts.push({
        severity: 'critical',
        code: 'cash_over_limit',
        title: 'เงินสดเกินวงเงินเก็บรักษา',
        message: `ยอดเงินสด ณ ${today} เกินเพดานที่กำหนด — ต้องนำฝากหรือนำส่งภายใน 3 วันทำการ`,
        due_date: today,
      });
    }
  } catch (_) {}

  return { data: { date: today, alerts } };
}

async function closeDay(bodyData) {
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp' };
  }
  const closeDate = parseDate(bodyData.close_date || bodyData.closeDate);
  const note = (bodyData.note || '').toString().trim() || null;
  const userId = parseInt(String(bodyData.refuser || bodyData.user_id || ''), 10) || null;

  const existing = await db('daily_closing').where('close_date', closeDate).first('id');
  if (existing) {
    return { status: 'error', message: `วันที่ ${closeDate} ปิดวันแล้ว — ไม่สามารถปิดซ้ำได้` };
  }

  const snapshot = await getDailyBalance({ date: closeDate });
  if (!snapshot?.data) {
    return { status: 'error', message: 'ไม่สามารถคำนวณรายงานเงินคงเหลือได้' };
  }

  if (snapshot.data.cash_over_limit) {
    return {
      status: 'error',
      message:
        'ยอดเงินสดเกินวงเงินเก็บรักษา — ต้องนำฝาก/นำส่งก่อนปิดวัน หรือบันทึกเหตุผลในงบเทียบยอดธนาคาร',
    };
  }

  const [id] = await db('daily_closing').insert({
    close_date: closeDate,
    snapshot_json: JSON.stringify(snapshot.data),
    closed_by: userId,
    note,
  });

  return {
    status: 'success',
    message: `ปิดวัน ${closeDate} เรียบร้อย`,
    data: { id, close_date: closeDate },
  };
}

async function listDailyClosings(query = {}) {
  const limit = Math.min(parseInt(query.limit, 10) || 30, 100);
  const rows = await db('daily_closing')
    .orderBy('close_date', 'desc')
    .limit(limit)
    .select('id', 'close_date', 'closed_by', 'closed_at', 'note');
  return { data: rows };
}

async function getDailyClosing(query = {}) {
  const closeDate = parseDate(query.date || query.close_date);
  const row = await db('daily_closing').where('close_date', closeDate).first();
  if (!row) return { data: null };
  let snapshot = null;
  try {
    snapshot = typeof row.snapshot_json === 'string'
      ? JSON.parse(row.snapshot_json)
      : row.snapshot_json;
  } catch (_) {}
  return {
    data: {
      ...row,
      snapshot,
    },
  };
}

async function saveReconciliationAdjustment(bodyData) {
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp' };
  }
  const asOf = parseDate(bodyData.as_of_date || bodyData.asOfDate);
  const reasonCode = (bodyData.reason_code || bodyData.reasonCode || '').toString().trim();
  if (!REASON_CODES.has(reasonCode)) {
    return { status: 'error', message: 'reason_code ไม่ถูกต้อง' };
  }
  const amount = parseFloat(String(bodyData.amount ?? '0').replace(/,/g, ''));
  const note = (bodyData.note || '').toString().trim() || null;
  const refBank = parseInt(String(bodyData.ref_bankaccount ?? bodyData.refBankAccount ?? ''), 10);
  const userId = parseInt(String(bodyData.refuser || bodyData.user_id || ''), 10) || null;

  const [id] = await db('bank_reconciliation_adjustment').insert({
    as_of_date: asOf,
    ref_bankaccount: Number.isFinite(refBank) && refBank > 0 ? refBank : null,
    reason_code: reasonCode,
    amount: Number.isFinite(amount) ? amount : 0,
    note,
    created_by: userId,
  });

  return { status: 'success', message: 'บันทึกเหตุผลความต่างยอดธนาคารแล้ว', data: { id } };
}

async function listReconciliationAdjustments(query = {}) {
  const asOf = parseDate(query.date || query.as_of_date);
  const rows = await db('bank_reconciliation_adjustment')
    .where('as_of_date', asOf)
    .orderBy('id', 'desc');
  return { data: rows };
}

module.exports = {
  getComplianceAlerts,
  closeDay,
  listDailyClosings,
  getDailyClosing,
  saveReconciliationAdjustment,
  listReconciliationAdjustments,
};
