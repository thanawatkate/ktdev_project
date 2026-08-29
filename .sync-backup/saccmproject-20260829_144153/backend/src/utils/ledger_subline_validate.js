const db = require('../configs/db.config');

function parsePositiveInt(v) {
  const n = parseInt(String(v ?? '').trim(), 10);
  return Number.isInteger(n) && n > 0 ? n : null;
}

/**
 * ลำดับเดียวกับรายงานเทียบยอดธนาคาร: หัวเอกสาร → แหล่งเงิน → ประเภทรายรับ
 * @param {Record<string, unknown>|null|undefined} headerCtx refbankaccount / refbudgetsource จากหัว income|expense
 * @param {{ refbankaccount?: unknown }} incometypeRow
 */
async function resolveEffectiveBankAccountId(headerCtx, incometypeRow) {
  const rawDoc = headerCtx?.refbankaccount ?? headerCtx?.refBankAccount;
  const nDoc = parseInt(String(rawDoc ?? '').trim(), 10);
  if (Number.isFinite(nDoc) && nDoc > 0) return nDoc;
  const rbs = parsePositiveInt(headerCtx?.refbudgetsource ?? headerCtx?.refBudgetSource);
  if (rbs) {
    const bs = await db('budgetsource').where('id', rbs).first('refbankaccount');
    const nBs = parseInt(String(bs?.refbankaccount ?? '').trim(), 10);
    if (Number.isFinite(nBs) && nBs > 0) return nBs;
  }
  const nIt = parseInt(String(incometypeRow?.refbankaccount ?? '').trim(), 10);
  if (Number.isFinite(nIt) && nIt > 0) return nIt;
  return null;
}

/**
 * ตรวจบรรทัดย่อยรายรับก่อนบันทึก — ให้รายงานคงเหลือ / บัญชีธนาคารถูกต้อง
 * @param {unknown[]} rows
 * @param {Record<string, unknown>|null|undefined} headerCtx จากหัว income (refbankaccount, refbudgetsource)
 */
async function assertIncomeSubRowsForReporting(rows, headerCtx) {
  const rbsH = parsePositiveInt(headerCtx?.refbudgetsource ?? headerCtx?.refBudgetSource);
  if (!rbsH) {
    throw new Error('หัวเอกสารรายรับ: ต้องระบุแหล่งเงิน (refbudgetsource)');
  }
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error('บรรทัดรายรับต้องมีอย่างน้อย 1 รายการ');
  }
  for (let i = 0; i < rows.length; i += 1) {
    const r = rows[i];
    const line = i + 1;
    const rtc = parsePositiveInt(r.refincometype ?? r.refIncomeType);
    const rmt = parsePositiveInt(r.refmoneytype ?? r.refMoneyType);
    if (!rtc) {
      throw new Error(`บรรทัดรายรับ ${line}: ต้องระบุประเภทรายรับ (refincometype)`);
    }
    if (!rmt) {
      throw new Error(`บรรทัดรายรับ ${line}: ต้องระบุประเภทเงิน (refmoneytype) — ใช้จำแนกเงินสด/ฝากธนาคาร/สปช. ในรายงาน`);
    }
    const it = await db('incometype').where('id', rtc).first('id', 'refbankaccount', 'use');
    if (!it) throw new Error(`บรรทัดรายรับ ${line}: ไม่พบประเภทรายรับ id ${rtc}`);
    if (String(it.use || 'Y').toUpperCase() === 'N') {
      throw new Error(`บรรทัดรายรับ ${line}: ประเภทรายรับ id ${rtc} ถูกปิดใช้งาน`);
    }
    const effectiveBank = await resolveEffectiveBankAccountId(headerCtx, it);
    if (!effectiveBank) {
      throw new Error(
        `บรรทัดรายรับ ${line}: ยังไม่มีบัญชีธนาคารตามลำดับหัวเอกสาร / แหล่งเงิน / ประเภทรายรับ — ตรวจสอบการผูกบัญชี`,
      );
    }
    const mt = await db('moneytype').where('id', rmt).first('id');
    if (!mt) throw new Error(`บรรทัดรายรับ ${line}: ไม่พบประเภทเงิน id ${rmt}`);
  }
}

/**
 * ตรวจบรรทัดย่อยรายจ่าย — เงินนอกงบฯ ต้องมี refincometype เพื่อผูกบัญชีจากประเภทรายรับ
 * @param {Array} rows
 * @param {string|null|undefined} moneyDomain 'off_budget' | 'budget' | null
 * @param {Record<string, unknown>|null|undefined} headerCtx จากหัว expense (refbankaccount, refbudgetsource)
 */
async function assertExpenseSubRowsForReporting(rows, moneyDomain, headerCtx) {
  const rbsH = parsePositiveInt(headerCtx?.refbudgetsource ?? headerCtx?.refBudgetSource);
  if (!rbsH) {
    throw new Error('หัวเอกสารรายจ่าย: ต้องระบุแหล่งเงิน (refbudgetsource)');
  }
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error('บรรทัดรายจ่ายต้องมีอย่างน้อย 1 รายการ');
  }
  const needObType = String(moneyDomain || '').toLowerCase() === 'off_budget';
  for (let i = 0; i < rows.length; i += 1) {
    const r = rows[i];
    const line = i + 1;
    const rmt = parsePositiveInt(r.refmoneytype ?? r.refMoneyType);
    if (!rmt) {
      throw new Error(`บรรทัดรายจ่าย ${line}: ต้องระบุประเภทเงิน (refmoneytype)`);
    }
    const mt = await db('moneytype').where('id', rmt).first('id');
    if (!mt) throw new Error(`บรรทัดรายจ่าย ${line}: ไม่พบประเภทเงิน id ${rmt}`);
    if (needObType) {
      const rtc = parsePositiveInt(r.refincometype ?? r.refFundCategory);
      if (!rtc) {
        throw new Error(`บรรทัดรายจ่าย ${line}: เงินนอกงบประมาณต้องระบุหมวดประเภทรายรับ (refincometype / refFundCategory)`);
      }
      const it = await db('incometype').where('id', rtc).first('id', 'refbankaccount', 'use');
      if (!it) throw new Error(`บรรทัดรายจ่าย ${line}: ไม่พบประเภทรายรับ id ${rtc}`);
      if (String(it.use || 'Y').toUpperCase() === 'N') {
        throw new Error(`บรรทัดรายจ่าย ${line}: ประเภทรายรับ id ${rtc} ถูกปิดใช้งาน`);
      }
      const effectiveBank = await resolveEffectiveBankAccountId(headerCtx, it);
      if (!effectiveBank) {
        throw new Error(
          `บรรทัดรายจ่าย ${line}: ยังไม่มีบัญชีธนาคารตามลำดับหัวเอกสาร / แหล่งเงิน / ประเภทรายรับ`,
        );
      }
    }
  }
}

module.exports = {
  assertIncomeSubRowsForReporting,
  assertExpenseSubRowsForReporting,
};
