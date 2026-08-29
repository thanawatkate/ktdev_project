const db = require('../../configs/db.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { writeAuditLog } = require('../../sacc_auditlog/auditlog.service');
const tableName = 'budgetsource';
const mapTableName = 'income_type_budget_source_map';

function mapBudgetSourceRow(row) {
  if (!row) return row;
  const refIt = row.refincometype == null ? null : Number(row.refincometype);
  const refMg = row.refmoneygroup == null ? null : Number(row.refmoneygroup);
  const refBa = row.refbankaccount == null ? null : Number(row.refbankaccount);
  const refIncomeTypes = Array.isArray(row.ref_income_types)
    ? row.ref_income_types.map((id) => Number(id)).filter((id) => Number.isInteger(id) && id > 0)
    : (refIt == null ? [] : [refIt]);
  return {
    ...row,
    refincometype: refIt,
    ref_income_type: refIt,
    refIncomeType: refIt,
    ref_income_types: refIncomeTypes,
    refIncomeTypes: refIncomeTypes,
    refmoneygroup: refMg,
    ref_money_group: refMg,
    refMoneyGroup: refMg,
    refbankaccount: refBa,
    ref_bank_account: refBa,
    refBankAccount: refBa,
    bank_account_name: row.bank_account_name ?? null,
    bankAccountName: row.bank_account_name ?? null,
  };
}

async function resolveRefIncomeType(raw) {
  if (typeof raw === 'undefined' || raw === null || raw === '') {
    return null;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error('รหัสหมวดรายรับไม่ถูกต้อง');
  }
  const exists = await db('incometype').where('id', parsed).first();
  if (!exists) {
    throw new Error('ไม่พบหมวดรายรับที่ต้องการอ้างอิง');
  }
  return parsed;
}

async function resolveRefIncomeTypes(raw) {
  if (typeof raw === 'undefined' || raw === null || raw === '') return null;
  const list = Array.isArray(raw) ? raw : [raw];
  const out = [];
  const seen = new Set();
  for (const item of list) {
    if (item === null || item === '' || typeof item === 'undefined') continue;
    const parsed = Number(item);
    if (!Number.isInteger(parsed) || parsed <= 0) {
      throw new Error('รหัสหมวดรายรับไม่ถูกต้อง');
    }
    if (seen.has(parsed)) continue;
    seen.add(parsed);
    out.push(parsed);
  }
  if (out.length === 0) return [];
  const rows = await db('incometype').whereIn('id', out).select('id');
  if (rows.length !== out.length) {
    throw new Error('พบรหัสหมวดรายรับที่ไม่มีอยู่ในระบบ');
  }
  return out;
}

async function readIncomeTypeMapByBudgetSourceIds(budgetSourceIds) {
  if (!Array.isArray(budgetSourceIds) || budgetSourceIds.length === 0) return {};
  let rows = [];
  try {
    rows = await db(mapTableName)
      .whereIn('refbudgetsource', budgetSourceIds)
      .select('refbudgetsource', 'refincometype');
  } catch (_) {
    return {};
  }
  const grouped = {};
  for (const row of rows) {
    const bsId = Number(row.refbudgetsource);
    const itId = Number(row.refincometype);
    if (!Number.isInteger(bsId) || !Number.isInteger(itId)) continue;
    if (!grouped[bsId]) grouped[bsId] = [];
    grouped[bsId].push(itId);
  }
  return grouped;
}

async function replaceIncomeTypeMap(trx, budgetSourceId, incomeTypeIds) {
  try {
    await trx(mapTableName).where('refbudgetsource', budgetSourceId).del();
  } catch (_) {
    return;
  }
  if (!Array.isArray(incomeTypeIds) || incomeTypeIds.length === 0) return;
  const rows = incomeTypeIds.map((id) => ({
    refincometype: id,
    refbudgetsource: budgetSourceId,
  }));
  await trx.batchInsert(mapTableName, rows, 100);
}

async function resolveRefMoneyGroup(raw) {
  if (typeof raw === 'undefined' || raw === null || raw === '') {
    return null;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error('รหัสประเภทเงินไม่ถูกต้อง');
  }
  const exists = await db('moneygroup').where('id', parsed).first();
  if (!exists) {
    throw new Error('ไม่พบประเภทเงินที่ต้องการอ้างอิง');
  }
  return parsed;
}

async function getAll(query = {}) {
  const fullSync =
    query.fullSync === '1' ||
    query.full_sync === '1' ||
    query.fullsync === '1';
  let q = db(tableName)
    .leftJoin('bankaccount as ba', `${tableName}.refbankaccount`, 'ba.id')
    .orderBy(`${tableName}.fiscal_year`, 'desc')
    .orderBy(`${tableName}.code`, 'asc');
  if (!fullSync) {
    q = q.where(`${tableName}.use`, 'Y');
  }
  if (query.fiscal_year) q = q.where(`${tableName}.fiscal_year`, query.fiscal_year);
  const rows = await q.select(`${tableName}.*`, 'ba.accountname as bank_account_name');
  const grouped = await readIncomeTypeMapByBudgetSourceIds(rows.map((r) => Number(r.id)));
  return {
    data: rows.map((row) =>
      mapBudgetSourceRow({
        ...row,
        ref_income_types: grouped[Number(row.id)] || [],
      }),
    ),
  };
}

async function getById(id) {
  const row = await db(tableName)
    .leftJoin('bankaccount as ba', `${tableName}.refbankaccount`, 'ba.id')
    .where(`${tableName}.id`, id)
    .select(`${tableName}.*`, 'ba.accountname as bank_account_name')
    .first();
  if (!row) return { status: 'error', message: 'ไม่พบข้อมูลแหล่งเงิน' };
  const grouped = await readIncomeTypeMapByBudgetSourceIds([Number(id)]);
  return {
    data: mapBudgetSourceRow({
      ...row,
      ref_income_types: grouped[Number(id)] || [],
    }),
  };
}

async function create(bodyData, meta = {}) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found' };
  if (checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };
  if (!bodyData.code) return { status: 'error', message: 'รหัสแหล่งเงินต้องไม่เป็นค่าว่าง' };
  if (!bodyData.name) return { status: 'error', message: 'ชื่อแหล่งเงินต้องไม่เป็นค่าว่าง' };
  if (!(bodyData.fiscal_year || bodyData.fiscalYear)) {
    return { status: 'error', message: 'ปีงบประมาณต้องไม่เป็นค่าว่าง' };
  }

  let refIncomeType = null;
  let refIncomeTypes = null;
  let refMoneyGroup = null;
  try {
    refIncomeTypes = await resolveRefIncomeTypes(
      bodyData.ref_income_types ?? bodyData.refIncomeTypes ?? bodyData.refincometypes,
    );
    refIncomeType = await resolveRefIncomeType(
      bodyData.ref_income_type ?? bodyData.refIncomeType ?? bodyData.refincometype,
    );
    if (refIncomeTypes === null && refIncomeType !== null) {
      refIncomeTypes = [refIncomeType];
    }
    if (Array.isArray(refIncomeTypes)) {
      refIncomeType = refIncomeTypes.length > 0 ? refIncomeTypes[0] : null;
    }
    refMoneyGroup = await resolveRefMoneyGroup(
      bodyData.ref_money_group ?? bodyData.refMoneyGroup ?? bodyData.refmoneygroup,
    );
  } catch (e) {
    return { status: 'error', message: e.message || String(e) };
  }

  const rawRefBa = bodyData.refbankaccount ?? bodyData.refBankAccount ?? bodyData.ref_bank_account;
  const refBankAccount = (rawRefBa == null || rawRefBa === '') ? null : (Number(rawRefBa) || null);

  let insertedId = null;
  await db.transaction(async (trx) => {
    const result = await trx(tableName).insert({
      code: bodyData.code,
      name: bodyData.name,
      description: bodyData.description || null,
      fiscal_year: bodyData.fiscal_year ?? bodyData.fiscalYear,
      budget_amount: parseFloat(bodyData.budget_amount ?? bodyData.budgetAmount) || 0,
      brought_forward_amount:
        parseFloat(bodyData.brought_forward_amount ?? bodyData.broughtForwardAmount) || 0,
      budget_type: bodyData.budget_type || bodyData.budgetType || 'งปม',
      refincometype: refIncomeType,
      refmoneygroup: refMoneyGroup,
      refbankaccount: refBankAccount,
      use: 'Y',
    });
    insertedId = result[0];
    if (Array.isArray(refIncomeTypes)) {
      await replaceIncomeTypeMap(trx, insertedId, refIncomeTypes);
    } else if (refIncomeType !== null) {
      await replaceIncomeTypeMap(trx, insertedId, [refIncomeType]);
    }
  });

  await writeAuditLog({
    tablename: tableName,
    record_id: insertedId,
    action: 'INSERT',
    new_data: JSON.stringify(bodyData),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });

  return { status: 'successfully', message: 'บันทึกข้อมูลสำเร็จ', id: insertedId };
}

async function update(id, bodyData, meta = {}) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found' };
  if (checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };

  const existing = await db(tableName).where('id', id).first();
  if (!existing) return { status: 'error', message: 'ไม่พบข้อมูลที่ต้องการแก้ไข' };

  const updateFields = {};
  if (bodyData.code) updateFields.code = bodyData.code;
  if (bodyData.name) updateFields.name = bodyData.name;
  if (bodyData.description !== undefined) updateFields.description = bodyData.description;
  if (bodyData.fiscal_year || bodyData.fiscalYear) {
    updateFields.fiscal_year = bodyData.fiscal_year ?? bodyData.fiscalYear;
  }
  if (bodyData.budget_amount !== undefined || bodyData.budgetAmount !== undefined) {
    updateFields.budget_amount = parseFloat(bodyData.budget_amount ?? bodyData.budgetAmount);
  }
  if (
    bodyData.brought_forward_amount !== undefined ||
    bodyData.broughtForwardAmount !== undefined
  ) {
    updateFields.brought_forward_amount =
      parseFloat(bodyData.brought_forward_amount ?? bodyData.broughtForwardAmount) || 0;
  }
  if (bodyData.budget_type || bodyData.budgetType) {
    updateFields.budget_type = bodyData.budget_type ?? bodyData.budgetType;
  }
  if (
    Object.prototype.hasOwnProperty.call(bodyData, 'ref_income_types') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'refIncomeTypes') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'refincometypes') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'ref_income_type') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'refIncomeType') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'refincometype')
  ) {
    try {
      let list = await resolveRefIncomeTypes(
        bodyData.ref_income_types ?? bodyData.refIncomeTypes ?? bodyData.refincometypes,
      );
      if (list === null) {
        const single = await resolveRefIncomeType(
          bodyData.ref_income_type ?? bodyData.refIncomeType ?? bodyData.refincometype,
        );
        list = single == null ? [] : [single];
      }
      updateFields.refincometype = list.length > 0 ? list[0] : null;
      updateFields.__refIncomeTypeList = list;
    } catch (e) {
      return { status: 'error', message: e.message || String(e) };
    }
  }
  if (
    Object.prototype.hasOwnProperty.call(bodyData, 'ref_money_group') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'refMoneyGroup') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'refmoneygroup')
  ) {
    try {
      updateFields.refmoneygroup = await resolveRefMoneyGroup(
        bodyData.ref_money_group ?? bodyData.refMoneyGroup ?? bodyData.refmoneygroup,
      );
    } catch (e) {
      return { status: 'error', message: e.message || String(e) };
    }
  }
  if (
    Object.prototype.hasOwnProperty.call(bodyData, 'refbankaccount') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'refBankAccount') ||
    Object.prototype.hasOwnProperty.call(bodyData, 'ref_bank_account')
  ) {
    const raw = bodyData.refbankaccount ?? bodyData.refBankAccount ?? bodyData.ref_bank_account;
    updateFields.refbankaccount = (raw == null || raw === '') ? null : (Number(raw) || null);
  }
  if (bodyData.use) updateFields.use = bodyData.use;
  updateFields.updated = new Date();

  const mapList = updateFields.__refIncomeTypeList;
  delete updateFields.__refIncomeTypeList;
  await db.transaction(async (trx) => {
    await trx(tableName).where('id', id).update(updateFields);
    if (Array.isArray(mapList)) {
      await replaceIncomeTypeMap(trx, Number(id), mapList);
    }
  });

  await writeAuditLog({
    tablename: tableName,
    record_id: parseInt(id),
    action: 'UPDATE',
    old_data: JSON.stringify(existing),
    new_data: JSON.stringify(updateFields),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });

  return { status: 'successfully', message: 'อัปเดตข้อมูลสำเร็จ' };
}

async function remove(id, bodyData, meta = {}) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found' };
  if (checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp' };

  const existing = await db(tableName).where('id', id).first();
  if (!existing) return { status: 'error', message: 'ไม่พบข้อมูลที่ต้องการลบ' };

  // Soft delete
  await db(tableName).where('id', id).update({ use: 'N', updated: new Date() });

  await writeAuditLog({
    tablename: tableName,
    record_id: parseInt(id),
    action: 'DELETE',
    old_data: JSON.stringify(existing),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });

  return { status: 'successfully', message: 'ลบข้อมูลสำเร็จ' };
}

// อัปเดต used_amount เมื่อมีการบันทึก expense
async function updateUsedAmount(budgetSourceId) {
  if (!budgetSourceId) return;
  const result = await db('expense')
    .where('refbudgetsource', budgetSourceId)
    .sum('amount as total')
    .first();
  const total = parseFloat(result.total) || 0;
  await db(tableName).where('id', budgetSourceId).update({ used_amount: total, updated: new Date() });
}

module.exports = { getAll, getById, create, update, remove, updateUsedAmount };
