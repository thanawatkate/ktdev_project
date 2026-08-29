const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { writeAuditLog } = require('../../sacc_auditlog/auditlog.service');
const { createdocno } = require('../../sacc_docgroup/services/saccdocgroup.service');
const {
  assertIncomeSubRowsForReporting,
  assertExpenseSubRowsForReporting,
} = require('../../utils/ledger_subline_validate');
const {
  PERM,
  assertDepositPermission,
} = require('../../utils/register_deposit_permission.util');

const TBL = 'deposit_guarantee';

/** moneygroup.id ตาม seed — ห้ามสลับ */
const MG_TAX = 3;
const MG_GUARANTEE = 4;

const VALID_DEPOSIT_TYPES = new Set(['contract_guarantee', 'withholding_tax', 'other']);
const SETTLE_STATUSES = new Set(['returned', 'submitted', 'forfeited']);

function parsePositiveInt(v) {
  const n = parseInt(String(v ?? '').trim(), 10);
  return Number.isInteger(n) && n > 0 ? n : null;
}

function parseAmount(v) {
  const n = parseFloat(String(v ?? '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : 0;
}

function parseDate(raw) {
  if (raw === undefined || raw === null || raw === '') return new Date();
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? new Date() : d;
}

function expectedMoneyGroup(depositType) {
  if (depositType === 'contract_guarantee') return MG_GUARANTEE;
  if (depositType === 'withholding_tax') return MG_TAX;
  return null;
}

async function assertToken(body) {
  if (!body.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(body.token)) return { status: 'error', message: 'Token exp' };
  return null;
}

async function resolvePartyIdPayer(bodyData) {
  const refParty = Number(bodyData.refparty);
  if (Number.isFinite(refParty) && refParty > 0) {
    const found = await db('party').where('id', refParty).first();
    if (found) return found.id;
  }
  const partyName = (bodyData.party_name_snapshot || bodyData.partyname || '').toString().trim();
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

async function resolvePartyIdReceiver(bodyData) {
  const refParty = Number(bodyData.refparty);
  if (Number.isFinite(refParty) && refParty > 0) {
    const found = await db('party').where('id', refParty).first();
    if (found) return found.id;
  }
  const partyName = (bodyData.party_name_snapshot || bodyData.partyname || '').toString().trim();
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

async function loadBudgetSource(refBudgetSourceId, depositType) {
  const row = await db('budgetsource')
    .where('id', refBudgetSourceId)
    .first('id', 'refmoneygroup', 'refincometype', 'refbankaccount', 'name');
  if (!row) {
    throw new Error('ไม่พบแหล่งเงินที่ระบุ');
  }
  const expectedMg = expectedMoneyGroup(depositType);
  if (expectedMg != null && Number(row.refmoneygroup) !== expectedMg) {
    const label =
      depositType === 'contract_guarantee'
        ? 'เงินประกันสัญญา'
        : 'เงินภาษีหัก ณ ที่จ่าย';
    throw new Error(`แหล่งเงินต้องเป็นประเภท "${label}" (refmoneygroup=${expectedMg})`);
  }
  return row;
}

function resolveRefIncomeType(body, budgetSourceRow) {
  return (
    parsePositiveInt(body.refincometype ?? body.refIncomeType) ||
    parsePositiveInt(budgetSourceRow.refincometype)
  );
}

async function list(page = 1, query = {}) {
  const offset = helper.getOffset(page, config.listPerPage);
  const builder = db(`${TBL} as d`)
    .leftJoin('party as p', 'd.refparty', 'p.id')
    .leftJoin('bankaccount as ba', 'd.refbankaccount', 'ba.id')
    .leftJoin('bank as b', 'ba.refbank', 'b.id')
    .leftJoin('income as inc', 'd.ref_income_id', 'inc.id')
    .leftJoin('expense as exp', 'd.ref_expense_id', 'exp.id')
    .select(
      'd.id',
      'd.docno',
      'd.docdate',
      'd.deposit_type',
      'd.amount',
      'd.contract_no',
      'd.detail',
      'd.due_date',
      'd.status',
      'd.settled_at',
      'd.settled_docno',
      'd.settled_remark',
      'd.fiscal_year',
      'd.ref_income_id',
      'd.ref_expense_id',
      'p.name as party_name',
      'd.party_name_snapshot',
      'b.name as bank_name',
      'ba.accountnumber as bank_account_no',
      'inc.docno as income_docno',
      'exp.docno as expense_docno',
    )
    .orderBy('d.docdate', 'desc')
    .orderBy('d.id', 'desc')
    .limit(config.listPerPage)
    .offset(offset);

  if (query.deposit_type) builder.where('d.deposit_type', query.deposit_type);
  if (query.status) builder.where('d.status', query.status);
  if (query.fiscal_year) builder.where('d.fiscal_year', query.fiscal_year);

  return { data: helper.emptyOrRows(await builder) };
}

async function getById(id) {
  const pk = parsePositiveInt(id);
  if (!pk) throw new Error('รหัสรายการไม่ถูกต้อง');

  const row = await db(`${TBL} as d`)
    .leftJoin('party as p', 'd.refparty', 'p.id')
    .leftJoin('bankaccount as ba', 'd.refbankaccount', 'ba.id')
    .leftJoin('bank as b', 'ba.refbank', 'b.id')
    .leftJoin('income as inc', 'd.ref_income_id', 'inc.id')
    .leftJoin('expense as exp', 'd.ref_expense_id', 'exp.id')
    .select(
      'd.id',
      'd.docno',
      'd.docdate',
      'd.deposit_type',
      'd.amount',
      'd.contract_no',
      'd.detail',
      'd.due_date',
      'd.status',
      'd.settled_at',
      'd.settled_docno',
      'd.settled_remark',
      'd.fiscal_year',
      'd.ref_income_id',
      'd.ref_expense_id',
      'd.refparty',
      'd.refbankaccount',
      'p.name as party_name',
      'd.party_name_snapshot',
      'b.name as bank_name',
      'ba.accountnumber as bank_account_no',
      'inc.docno as income_docno',
      'exp.docno as expense_docno',
    )
    .where('d.id', pk)
    .first();

  if (!row) throw new Error('ไม่พบรายการทะเบียน');
  return { status: 'successfully', data: row };
}

async function create(body, meta = {}) {
  const permErr = await assertDepositPermission(body, meta, PERM.create);
  if (permErr) return permErr;
  const tokenErr = await assertToken(body);
  if (tokenErr) return tokenErr;

  if (body.create_income === true || body.create_income === 'true') {
    return receiveWithIncome(body, meta);
  }

  if (!body.docno) return { status: 'error', message: 'docno require' };
  if (!body.deposit_type || !VALID_DEPOSIT_TYPES.has(body.deposit_type)) {
    return { status: 'error', message: 'deposit_type ไม่ถูกต้อง' };
  }
  const amount = parseAmount(body.amount);
  if (amount <= 0) return { status: 'error', message: 'amount ต้องมากกว่า 0' };

  const insertData = {
    docno: body.docno,
    docdate: parseDate(body.docdate),
    deposit_type: body.deposit_type,
    amount,
    refparty: parsePositiveInt(body.refparty) || null,
    party_name_snapshot: body.party_name_snapshot || null,
    contract_no: body.contract_no || null,
    detail: body.detail || null,
    due_date: body.due_date ? parseDate(body.due_date) : null,
    refbankaccount: parsePositiveInt(body.refbankaccount ?? body.refBankAccount) || null,
    status: 'holding',
    fiscal_year: body.fiscal_year || null,
  };

  const r = await db(TBL).insert(insertData);
  const newId = Array.isArray(r) ? r[0] : r;
  await writeAuditLog({
    tablename: TBL,
    record_id: newId,
    action: 'INSERT',
    new_data: JSON.stringify(insertData),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });
  return {
    status: 'successfully',
    message: 'บันทึกทะเบียนเรียบร้อยแล้ว (ยังไม่มีใบรับเงิน — ยอดรายงานหน้า 34 อาจไม่ตรง)',
    lastid: newId,
  };
}

/**
 * รับเงินประกัน/ภาษีหัก ณ ที่จ่าย + สร้างใบรับเงินในธุรกรรมเดียว
 */
async function receiveWithIncome(body, meta = {}) {
  const permErr = await assertDepositPermission(body, meta, PERM.create);
  if (permErr) return permErr;
  const tokenErr = await assertToken(body);
  if (tokenErr) return tokenErr;

  if (!body.docno) return { status: 'error', message: 'docno require' };
  if (!body.deposit_type || !VALID_DEPOSIT_TYPES.has(body.deposit_type)) {
    return { status: 'error', message: 'deposit_type ไม่ถูกต้อง' };
  }

  const amount = parseAmount(body.amount);
  if (amount <= 0) return { status: 'error', message: 'amount ต้องมากกว่า 0' };

  const refBudgetSourceId = parsePositiveInt(body.refbudgetsource ?? body.refBudgetSource);
  if (!refBudgetSourceId) {
    return { status: 'error', message: 'refbudgetsource require — ระบุแหล่งเงินประเภทประกัน/ภาษีหัก' };
  }

  const refMoneyType = parsePositiveInt(body.refmoneytype ?? body.refMoneyType);
  if (!refMoneyType) {
    return { status: 'error', message: 'refmoneytype require — ระบุช่องทางเงิน (สด/ฝาก/สปช.)' };
  }

  const refUser = parsePositiveInt(body.refuser ?? body.refUser);
  if (!refUser) {
    return { status: 'error', message: 'refuser require' };
  }

  let budgetSourceRow;
  try {
    budgetSourceRow = await loadBudgetSource(refBudgetSourceId, body.deposit_type);
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }

  const refincometype = resolveRefIncomeType(body, budgetSourceRow);
  if (!refincometype) {
    return {
      status: 'error',
      message:
        'refincometype require — ระบุหมวดรายรับหรือผูก refincometype ที่แหล่งเงิน',
    };
  }

  const refbankaccount =
    parsePositiveInt(body.refbankaccount ?? body.refBankAccount) ||
    parsePositiveInt(budgetSourceRow.refbankaccount);

  const docdateVal = parseDate(body.docdate);
  const subdata = [
    {
      refincometype,
      refmoneytype: refMoneyType,
      amount: parseFloat(amount.toFixed(2)),
      remark: body.detail || '',
    },
  ];

  const incomeHeaderCtx = {
    refbankaccount,
    refbudgetsource: refBudgetSourceId,
  };

  try {
    await assertIncomeSubRowsForReporting(subdata, incomeHeaderCtx);
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }

  let incomeDocNo = (body.income_docno || body.docno || '').toString().trim();
  if (!incomeDocNo) {
    try {
      incomeDocNo = await createdocno({ tablename: 'income', docdate: docdateVal });
    } catch (_) {
      incomeDocNo = body.docno;
    }
  }

  const refparty = await resolvePartyIdPayer(body);
  const detail =
    (body.income_detail || body.detail || `รับ${body.deposit_type === 'withholding_tax' ? 'ภาษีหัก ณ ที่จ่าย' : 'เงินประกันสัญญา'}`).toString();

  let depositId;
  let incomeId;

  try {
    await db.transaction(async (trx) => {
      const incomeInsert = {
        amount: parseFloat(amount.toFixed(2)),
        docno: incomeDocNo,
        docdate: docdateVal,
        detail,
        remark: body.remark || '',
        refuser: refUser,
        refmoneytype: refMoneyType,
        refbudgetsource: refBudgetSourceId,
        refparty,
        refbankaccount,
        money_domain: 'off_budget',
        doc_status: 'posted',
        posted_at: trx.fn.now(),
      };
      const incomeResult = await trx('income').insert(incomeInsert);
      incomeId = Array.isArray(incomeResult) ? incomeResult[0] : incomeResult;

      for (const row of subdata) {
        await trx('incomesub').insert({
          refincome: incomeId,
          refincometype: row.refincometype,
          refmoneytype: row.refmoneytype,
          amount: row.amount,
          remark: row.remark || '',
        });
      }

      const depositInsert = {
        docno: body.docno,
        docdate: docdateVal,
        deposit_type: body.deposit_type,
        amount: parseFloat(amount.toFixed(2)),
        refparty,
        party_name_snapshot: body.party_name_snapshot || null,
        contract_no: body.contract_no || null,
        detail: body.detail || null,
        due_date: body.due_date ? parseDate(body.due_date) : null,
        refbankaccount,
        status: 'holding',
        fiscal_year: body.fiscal_year || null,
        ref_income_id: incomeId,
      };

      const depResult = await trx(TBL).insert(depositInsert);
      depositId = Array.isArray(depResult) ? depResult[0] : depResult;
    });
  } catch (e) {
    return { status: 'error', message: e.message || 'บันทึกไม่สำเร็จ' };
  }

  await writeAuditLog({
    tablename: TBL,
    record_id: depositId,
    action: 'INSERT',
    new_data: JSON.stringify({ depositId, incomeId, amount }),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });

  const depositRow = await db(TBL).where('id', depositId).first();

  return {
    status: 'successfully',
    message: 'บันทึกรับเงินและทะเบียนประกันเรียบร้อยแล้ว',
    lastid: depositId,
    deposit_id: depositId,
    income_id: incomeId,
    income_docno: incomeDocNo,
    data: depositRow,
  };
}

/**
 * คืน/นำส่ง/ริบ + สร้างใบจ่าย (เมื่อ create_expense !== false)
 */
async function returnWithExpense(id, body, meta = {}) {
  const permErr = await assertDepositPermission(body, meta, PERM.settle);
  if (permErr) return permErr;
  const tokenErr = await assertToken(body);
  if (tokenErr) return tokenErr;

  const found = await db(TBL).where('id', id).first();
  if (!found) return { status: 'error', message: 'ไม่พบข้อมูล' };
  if (found.status !== 'holding') {
    return { status: 'error', message: 'รายการนี้ดำเนินการแล้ว ไม่สามารถคืน/นำส่งซ้ำได้' };
  }

  const status = (body.status || 'returned').toString();
  if (!SETTLE_STATUSES.has(status)) {
    return { status: 'error', message: 'status ต้องเป็น returned/submitted/forfeited' };
  }

  const skipExpense =
    body.create_expense === false || body.create_expense === 'false';
  if (skipExpense) {
    return settle(id, body, meta);
  }

  const amount = parseAmount(body.amount ?? found.amount);
  if (amount <= 0) return { status: 'error', message: 'amount ต้องมากกว่า 0' };

  const refBudgetSourceId =
    parsePositiveInt(body.refbudgetsource ?? body.refBudgetSource) ||
    (found.ref_income_id
      ? parsePositiveInt(
          (
            await db('income')
              .where('id', found.ref_income_id)
              .first('refbudgetsource')
          )?.refbudgetsource,
        )
      : null);

  if (!refBudgetSourceId) {
    return { status: 'error', message: 'refbudgetsource require — ระบุแหล่งเงิน' };
  }

  const refMoneyType = parsePositiveInt(body.refmoneytype ?? body.refMoneyType);
  if (!refMoneyType) {
    return { status: 'error', message: 'refmoneytype require' };
  }

  let budgetSourceRow;
  try {
    budgetSourceRow = await loadBudgetSource(refBudgetSourceId, found.deposit_type);
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }

  const refincometype = resolveRefIncomeType(body, budgetSourceRow);
  const subdata = [
    {
      refincometype: refincometype || null,
      refmoneytype: refMoneyType,
      amount: parseFloat(amount.toFixed(2)),
      remark: body.settled_remark || body.remark || '',
    },
  ];

  const refbankaccount =
    parsePositiveInt(body.refbankaccount ?? body.refBankAccount) ||
    parsePositiveInt(budgetSourceRow.refbankaccount);

  const expenseHeaderCtx = {
    refbankaccount,
    refbudgetsource: refBudgetSourceId,
  };

  try {
    await assertExpenseSubRowsForReporting(subdata, null, expenseHeaderCtx);
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }

  let expenseDocNo = (body.expense_docno || body.settled_docno || '').toString().trim();
  const docdateVal = parseDate(body.settled_at || body.docdate || new Date());
  if (!expenseDocNo) {
    try {
      expenseDocNo = await createdocno({ tablename: 'expense', docdate: docdateVal });
    } catch (_) {
      expenseDocNo = `OUT-${found.docno}`;
    }
  }

  const refparty = await resolvePartyIdReceiver(body);
  const detail =
    body.expense_detail ||
    body.settled_remark ||
    `คืน${found.deposit_type === 'withholding_tax' ? 'ภาษีหัก ณ ที่จ่าย' : 'เงินประกันสัญญา'} ${found.docno}`;

  let expenseId;

  try {
    await db.transaction(async (trx) => {
      const expenseInsert = {
        docno: expenseDocNo,
        docdate: docdateVal,
        amount: parseFloat(amount.toFixed(2)),
        chequeamount: 0,
        bankamount: parseFloat(amount.toFixed(2)),
        detail,
        remark: body.settled_remark || '',
        refmember: parsePositiveInt(body.refmember ?? body.refMember) || null,
        refbudgetsource: refBudgetSourceId,
        refparty,
        money_domain: null,
        doc_status: 'posted',
        refbankaccount,
      };
      const expResult = await trx('expense').insert(expenseInsert);
      expenseId = Array.isArray(expResult) ? expResult[0] : expResult;

      for (const row of subdata) {
        await trx('expensesub').insert({
          refexpense: expenseId,
          refexpensetype: parsePositiveInt(row.refexpensetype) || null,
          refincometype: row.refincometype,
          refmoneytype: row.refmoneytype,
          amount: row.amount,
          remark: row.remark || '',
        });
      }

      await trx(TBL)
        .where('id', id)
        .update({
          status,
          settled_at: docdateVal,
          settled_docno: body.settled_docno || expenseDocNo,
          settled_remark: body.settled_remark || null,
          ref_expense_id: expenseId,
          updated: trx.fn.now(),
        });
    });
  } catch (e) {
    return { status: 'error', message: e.message || 'บันทึกไม่สำเร็จ' };
  }

  await writeAuditLog({
    tablename: TBL,
    record_id: parseInt(id, 10),
    action: 'UPDATE',
    old_data: JSON.stringify(found),
    new_data: JSON.stringify({ status, expenseId }),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });

  const depositRow = await db(TBL).where('id', id).first();

  return {
    status: 'successfully',
    message: 'บันทึกการคืน/นำส่งและใบจ่ายเรียบร้อยแล้ว',
    expense_id: expenseId,
    expense_docno: expenseDocNo,
    data: depositRow,
  };
}

async function update(id, body, meta = {}) {
  const permErr = await assertDepositPermission(body, meta, PERM.update);
  if (permErr) return permErr;
  const tokenErr = await assertToken(body);
  if (tokenErr) return tokenErr;

  const found = await db(TBL).where('id', id).first();
  if (!found) return { status: 'error', message: 'ไม่พบข้อมูล' };
  if (found.status !== 'holding') {
    return { status: 'error', message: 'แก้ไขได้เฉพาะรายการที่สถานะ "ถือไว้"' };
  }

  const allow = [
    'docno',
    'docdate',
    'deposit_type',
    'amount',
    'refparty',
    'party_name_snapshot',
    'contract_no',
    'detail',
    'due_date',
    'refbankaccount',
    'fiscal_year',
  ];
  const updateFields = {};
  for (const k of allow) {
    if (typeof body[k] !== 'undefined') updateFields[k] = body[k];
  }

  if (typeof updateFields.amount !== 'undefined') {
    updateFields.amount = parseFloat(parseAmount(updateFields.amount).toFixed(2));
  }
  if (typeof updateFields.docdate !== 'undefined') {
    updateFields.docdate = parseDate(updateFields.docdate);
  }
  if (typeof updateFields.due_date !== 'undefined' && updateFields.due_date) {
    updateFields.due_date = parseDate(updateFields.due_date);
  }

  if (!Object.keys(updateFields).length) {
    return { status: 'error', message: 'ไม่มีข้อมูลสำหรับอัปเดต' };
  }

  await db(TBL).where('id', id).update({ ...updateFields, updated: db.fn.now() });
  await writeAuditLog({
    tablename: TBL,
    record_id: parseInt(id, 10),
    action: 'UPDATE',
    old_data: JSON.stringify(found),
    new_data: JSON.stringify(updateFields),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });
  return { status: 'successfully', message: 'อัปเดตข้อมูลเรียบร้อยแล้ว' };
}

async function remove(id, body, meta = {}) {
  const permErr = await assertDepositPermission(body, meta, PERM.delete);
  if (permErr) return permErr;
  const tokenErr = await assertToken(body);
  if (tokenErr) return tokenErr;

  const found = await db(TBL).where('id', id).first();
  if (!found) return { status: 'successfully', message: 'ไม่พบข้อมูล' };
  if (found.status !== 'holding') {
    return { status: 'error', message: 'ลบได้เฉพาะรายการที่สถานะ "ถือไว้"' };
  }
  if (found.ref_income_id) {
    return {
      status: 'error',
      message: 'รายการนี้ผูกใบรับเงินแล้ว — ให้ยกเลิกใบรับเงินก่อน หรือใช้การปรับปรุงจากเมนูรายรับ',
    };
  }

  await db(TBL).where('id', id).del();
  await writeAuditLog({
    tablename: TBL,
    record_id: parseInt(id, 10),
    action: 'DELETE',
    old_data: JSON.stringify(found),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });
  return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อยแล้ว' };
}

async function settle(id, body, meta = {}) {
  const permErr = await assertDepositPermission(body, meta, PERM.settle);
  if (permErr) return permErr;
  const tokenErr = await assertToken(body);
  if (tokenErr) return tokenErr;

  if (body.create_expense === true || body.create_expense === 'true') {
    return returnWithExpense(id, body, meta);
  }

  const found = await db(TBL).where('id', id).first();
  if (!found) return { status: 'error', message: 'ไม่พบข้อมูล' };
  if (found.status !== 'holding') {
    return { status: 'error', message: 'รายการนี้ดำเนินการแล้ว' };
  }

  const status = body.status || 'returned';
  if (!SETTLE_STATUSES.has(status)) {
    return { status: 'error', message: 'status ต้องเป็น returned/submitted/forfeited' };
  }

  const updateData = {
    status,
    settled_at: body.settled_at ? parseDate(body.settled_at) : db.fn.now(),
    settled_docno: body.settled_docno || null,
    settled_remark: body.settled_remark || null,
  };
  await db(TBL).where('id', id).update({ ...updateData, updated: db.fn.now() });

  await writeAuditLog({
    tablename: TBL,
    record_id: parseInt(id, 10),
    action: 'UPDATE',
    old_data: JSON.stringify(found),
    new_data: JSON.stringify(updateData),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });
  return { status: 'successfully', message: 'บันทึกสถานะเรียบร้อยแล้ว' };
}

/**
 * กระทบยอดทะเบียน holding กับ movement แหล่งเงินตาม moneygroup
 */
async function reconciliation(query = {}) {
  const depositType = query.deposit_type || 'contract_guarantee';
  const expectedMg = expectedMoneyGroup(depositType);
  if (!expectedMg) {
    return { status: 'error', message: 'reconciliation รองรับ contract_guarantee / withholding_tax' };
  }

  const holdingRow = await db(TBL)
    .where({ deposit_type: depositType, status: 'holding' })
    .sum('amount as total')
    .first();
  const registerHolding = parseFloat(holdingRow?.total) || 0;

  const bsIds = await db('budgetsource').where('refmoneygroup', expectedMg).pluck('id');
  let ledgerNet = 0;
  if (bsIds.length > 0) {
    const [inSum, outSum] = await Promise.all([
      db('income as i')
        .leftJoin('incomesub as s', 'i.id', 's.refincome')
        .whereIn('i.refbudgetsource', bsIds)
        .sum('s.amount as t')
        .first(),
      db('expense as e')
        .leftJoin('expensesub as s', 'e.id', 's.refexpense')
        .whereIn('e.refbudgetsource', bsIds)
        .sum('s.amount as t')
        .first(),
    ]);
    ledgerNet =
      (parseFloat(inSum?.t) || 0) - (parseFloat(outSum?.t) || 0);
  }

  const diff = parseFloat((registerHolding - ledgerNet).toFixed(2));

  return {
    status: 'successfully',
    data: {
      deposit_type: depositType,
      money_group_id: expectedMg,
      register_holding_total: registerHolding,
      ledger_net_total: ledgerNet,
      difference: diff,
      balanced: Math.abs(diff) < 0.01,
    },
  };
}

/**
 * รายการ holding ที่ครบกำหนดคืนภายใน [days] วัน หรือเลยกำหนดแล้ว
 */
async function listDueSoon(query = {}) {
  const days = Math.min(Math.max(parseInt(String(query.days ?? '30'), 10) || 30, 1), 365);
  const fiscalYear = query.fiscal_year ? String(query.fiscal_year).trim() : null;

  const end = new Date();
  end.setHours(23, 59, 59, 999);
  end.setDate(end.getDate() + days);

  const builder = db(`${TBL} as d`)
    .leftJoin('party as p', 'd.refparty', 'p.id')
    .leftJoin('income as inc', 'd.ref_income_id', 'inc.id')
    .leftJoin('expense as exp', 'd.ref_expense_id', 'exp.id')
    .select(
      'd.id',
      'd.docno',
      'd.docdate',
      'd.deposit_type',
      'd.amount',
      'd.contract_no',
      'd.due_date',
      'd.status',
      'd.fiscal_year',
      'p.name as party_name',
      'd.party_name_snapshot',
      'inc.docno as income_docno',
      'exp.docno as expense_docno',
    )
    .where('d.status', 'holding')
    .whereNotNull('d.due_date')
    .where('d.due_date', '<=', end)
    .orderBy('d.due_date', 'asc')
    .orderBy('d.id', 'asc');

  if (fiscalYear) builder.where('d.fiscal_year', fiscalYear);

  const rows = helper.emptyOrRows(await builder);
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  let overdue = 0;
  let upcoming = 0;
  const data = rows.map((r) => {
    const due = new Date(r.due_date);
    due.setHours(0, 0, 0, 0);
    const daysLeft = Math.round((due.getTime() - today.getTime()) / 86400000);
    const isOverdue = daysLeft < 0;
    if (isOverdue) {
      overdue += 1;
    } else {
      upcoming += 1;
    }
    return {
      ...r,
      days_left: daysLeft,
      is_overdue: isOverdue,
    };
  });

  return {
    status: 'successfully',
    data,
    meta: { days, overdue_count: overdue, upcoming_count: upcoming, total: data.length },
  };
}

module.exports = {
  list,
  getById,
  create,
  receiveWithIncome,
  returnWithExpense,
  update,
  remove,
  settle,
  reconciliation,
  listDueSoon,
};
