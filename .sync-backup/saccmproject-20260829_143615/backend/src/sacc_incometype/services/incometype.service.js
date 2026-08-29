const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const tableName = 'incometype'
const mapTableName = 'income_type_budget_source_map';

async function resolveBudgetSourceIds(raw) {
  if (typeof raw === 'undefined' || raw === null || raw === '') return null;
  const list = Array.isArray(raw) ? raw : [raw];
  const out = [];
  const seen = new Set();
  for (const item of list) {
    if (item === null || item === '' || typeof item === 'undefined') continue;
    const id = Number(item);
    if (!Number.isInteger(id) || id <= 0) {
      throw new Error('รหัสแหล่งเงินไม่ถูกต้อง');
    }
    if (seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  if (out.length === 0) return [];
  const rows = await db('budgetsource').whereIn('id', out).select('id');
  if (rows.length !== out.length) {
    throw new Error('พบแหล่งเงินที่ไม่มีอยู่ในระบบ');
  }
  return out;
}

function ensureHasLinkedBudgetSources(list) {
  if (!Array.isArray(list) || list.length === 0) {
    throw new Error('กรุณาผูกแหล่งเงินอย่างน้อย 1 รายการก่อนบันทึกหมวดรายรับ');
  }
}

/**
 * หลายแหล่งเงินต่อหมวดรายรับ — อนุญาตเฉพาะเมื่อเป็นสายเดียวกัน (คู่มือ พ.ศ. 2544: แยกทะเบียนตามประเภทเงิน)
 * ตรวจ refmoneygroup, budget_type และ refincometype (legacy) ให้สอดคล้องกัน
 */
async function assertLinkedBudgetSourcesSchoolFinanceConsistent(budgetSourceIds) {
  if (!Array.isArray(budgetSourceIds) || budgetSourceIds.length <= 1) return;

  const rows = await db('budgetsource')
    .whereIn('id', budgetSourceIds)
    .select('id', 'code', 'refmoneygroup', 'budget_type', 'refincometype');

  if (rows.length !== budgetSourceIds.length) {
    throw new Error('พบแหล่งเงินที่ไม่มีอยู่ในระบบ');
  }

  const mgKey = (v) => {
    const n = parseInt(String(v ?? '').trim(), 10);
    return Number.isInteger(n) && n > 0 ? String(n) : '';
  };
  const mgVals = rows.map((r) => mgKey(r.refmoneygroup));
  if (mgVals.some((k) => k === '')) {
    throw new Error(
      'ผูกหลายแหล่งเงิน: ต้องกำหนดกลุ่มเงิน (refmoneygroup) ให้ครบทุกแหล่งก่อน — ตามหลักทะเบียนคุมแยกประเภท',
    );
  }
  const uniqMg = new Set(mgVals);
  if (uniqMg.size > 1) {
    throw new Error(
      'ผูกหลายแหล่งเงินได้เฉพาะเมื่อเป็นประเภทเงิน (กลุ่มเงิน) เดียวกัน — แหล่งที่เลือกไม่ตรงกัน',
    );
  }

  const btVals = rows.map((r) => String(r.budget_type ?? '').trim());
  const uniqBt = new Set(btVals.map((x) => (x === '' ? '__EMPTY__' : x)));
  if (uniqBt.size > 1) {
    throw new Error(
      'ผูกหลายแหล่งเงินได้เฉพาะเมื่อเป็นประเภทงบ (budget_type) เดียวกัน — แหล่งที่เลือกไม่ตรงกัน',
    );
  }

  const itVals = rows
    .map((r) => {
      const n = parseInt(String(r.refincometype ?? '').trim(), 10);
      return Number.isInteger(n) && n > 0 ? String(n) : '';
    })
    .filter((x) => x !== '');
  const uniqIt = new Set(itVals);
  if (uniqIt.size > 1) {
    throw new Error(
      'แหล่งเงินที่เลือกเคยผูกหมวดรายรับคนละหมวด — แยกหมวดหรือเลือกเฉพาะแหล่งในสายเดียวกันตามคู่มือ',
    );
  }
}

async function replaceIncomeTypeBudgetSourceMap(trx, incomeTypeId, budgetSourceIds) {
  await trx(mapTableName).where('refincometype', incomeTypeId).del();
  if (!Array.isArray(budgetSourceIds) || budgetSourceIds.length === 0) return;
  await trx.batchInsert(
    mapTableName,
    budgetSourceIds.map((bsId) => ({
      refincometype: incomeTypeId,
      refbudgetsource: bsId,
    })),
    100,
  );
}

async function loadLinkedBudgetSourceIdsMap(incomeTypeIds) {
  if (!Array.isArray(incomeTypeIds) || incomeTypeIds.length === 0) return {};
  let rows = [];
  try {
    rows = await db(mapTableName)
      .whereIn('refincometype', incomeTypeIds)
      .select('refincometype', 'refbudgetsource');
  } catch (_) {
    return {};
  }
  const map = {};
  for (const row of rows) {
    const itId = Number(row.refincometype);
    const bsId = Number(row.refbudgetsource);
    if (!Number.isInteger(itId) || !Number.isInteger(bsId)) continue;
    if (!map[itId]) map[itId] = [];
    map[itId].push(bsId);
  }
  return map;
}

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(tableName)
    .select('*')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);
  const data = helper.emptyOrRows(rows);
  const meta = { page };
  const linkedMap = await loadLinkedBudgetSourceIdsMap(
    data.map((row) => Number(row.id)).filter((id) => Number.isInteger(id) && id > 0),
  );
  const decorated = data.map((row) => {
    const id = Number(row.id);
    const linked = linkedMap[id] || [];
    return {
      ...row,
      linked_budget_source_ids: linked,
      linkedBudgetSourceIds: linked,
    };
  });
  return {
    data: decorated,
    meta
  }
}

async function create(bodyData) {
  const remark = bodyData.remark === undefined || bodyData.remark === null ? '' : String(bodyData.remark);

  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }
  if (bodyData.name === '' || typeof bodyData.name === 'undefined') {
    return { status: 'error', message: 'name  require ' };
  }
  if (bodyData.refmoneygroup === '' || typeof bodyData.refmoneygroup === 'undefined') {
    return { status: 'error', message: 'refmoneygroup require ' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  let linkedBudgetSourceIds = null;
  try {
    linkedBudgetSourceIds = await resolveBudgetSourceIds(
      bodyData.linked_budget_source_ids ??
        bodyData.linkedBudgetSourceIds ??
        bodyData.ref_budget_source_ids ??
        bodyData.refBudgetSourceIds,
    );
    ensureHasLinkedBudgetSources(linkedBudgetSourceIds);
    await assertLinkedBudgetSourcesSchoolFinanceConsistent(linkedBudgetSourceIds);
  } catch (e) {
    return {
      status: 'error',
      message: e.message || String(e),
    };
  }

  const rawBa = bodyData.refbankaccount ?? bodyData.refBankAccount ?? bodyData.refsaccbankaccount;
  let refbankaccount = null;
  if (rawBa !== undefined && rawBa !== null && rawBa !== '') {
    const n = parseInt(String(rawBa).trim(), 10);
    if (!Number.isInteger(n) || n <= 0) {
      return { status: 'error', message: 'refbankaccount ไม่ถูกต้อง' };
    }
    const bankRow = await db('bankaccount').where('id', n).first('id');
    if (!bankRow) {
      return { status: 'error', message: 'ไม่พบบัญชีธนาคารที่ระบุ' };
    }
    refbankaccount = n;
  }

  if (refbankaccount === null) {
    const rows = await db('budgetsource')
      .whereIn('id', linkedBudgetSourceIds)
      .select('id', 'code', 'refbankaccount');
    const missing = rows.filter((r) => {
      const x = parseInt(String(r.refbankaccount ?? '').trim(), 10);
      return !Number.isInteger(x) || x <= 0;
    });
    if (missing.length > 0) {
      return {
        status: 'error',
        message: `แหล่งเงินต้องผูกบัญชีธนาคารให้ครบก่อนสร้างหมวดรายรับ (ยังไม่มีบัญชี: ${missing.map((m) => m.code || m.id).join(', ')}) หรือระบุ refbankaccount ที่หมวด (legacy)`,
      };
    }
  }

  const refMg = parseInt(String(bodyData.refmoneygroup).trim(), 10);
  if (!Number.isInteger(refMg) || refMg <= 0) {
    return { status: 'error', message: 'refmoneygroup ไม่ถูกต้อง' };
  }

  let insertId;
  try {
    [insertId] = await db(tableName).insert({
      name: bodyData.name,
      remark,
      refbankaccount,
      refmoneygroup: refMg,
    });
  } catch (e) {
    return { status: 'error', message: e.message || 'บันทึกข้อมูลไม่สำเร็จ' };
  }

  if (!insertId) {
    return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
  }

  await db.transaction(async (trx) => {
    await replaceIncomeTypeBudgetSourceMap(trx, Number(insertId), linkedBudgetSourceIds);
  });

  return {
    status: 'successfully',
    message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
    lastId: insertId,
  };
}

async function update(id, bodyData) {
  if (id === '' || typeof id === 'undefined') {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }
  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const result = await db(tableName).where('id', '=', id).select();
  if (result.length < 1) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }

  const fliedData = {};
  if (typeof bodyData.name !== 'undefined') {
    if (bodyData.name === '' || bodyData.name === null) {
      return { status: 'error', message: 'name  require ' };
    }
    fliedData.name = bodyData.name;
  }
  if (typeof bodyData.remark !== 'undefined') {
    fliedData.remark = bodyData.remark ?? '';
  }
  if (typeof bodyData.sort !== 'undefined') {
    const s = Number(bodyData.sort);
    if (!Number.isInteger(s)) {
      return { status: 'error', message: 'sort ไม่ถูกต้อง' };
    }
    fliedData.sort = s;
  }

  const refBankRaw =
    bodyData.refbankaccount ?? bodyData.refBankAccount ?? bodyData.refsaccbankaccount;
  if (typeof refBankRaw !== 'undefined') {
    const n = parseInt(String(refBankRaw).trim(), 10);
    if (!Number.isInteger(n) || n <= 0) {
      return { status: 'error', message: 'refbankaccount require ' };
    }
    const bankRow = await db('bankaccount').where('id', n).first('id');
    if (!bankRow) {
      return { status: 'error', message: 'ไม่พบบัญชีธนาคารที่ระบุ' };
    }
    fliedData.refbankaccount = n;
  }

  const refMgRaw = bodyData.refmoneygroup ?? bodyData.refMoneyGroup;
  if (typeof refMgRaw !== 'undefined') {
    const n = parseInt(String(refMgRaw).trim(), 10);
    if (!Number.isInteger(n) || n <= 0) {
      return { status: 'error', message: 'refmoneygroup ไม่ถูกต้อง' };
    }
    const mgRow = await db('moneygroup').where('id', n).first('id');
    if (!mgRow) {
      return { status: 'error', message: 'ไม่พบกลุ่มเงินที่ระบุ' };
    }
    fliedData.refmoneygroup = n;
  }

  if (typeof bodyData.use !== 'undefined' && bodyData.use !== '' && bodyData.use !== null) {
    const u = String(bodyData.use).trim().toUpperCase();
    if (u !== 'Y' && u !== 'N') {
      return { status: 'error', message: 'use ต้องเป็น Y หรือ N' };
    }
    fliedData.use = u;
  }

  const linkedBudgetSourceIdsInput =
    bodyData.linked_budget_source_ids ??
    bodyData.linkedBudgetSourceIds ??
    bodyData.ref_budget_source_ids ??
    bodyData.refBudgetSourceIds;

  if (Object.keys(fliedData).length < 1 && typeof linkedBudgetSourceIdsInput === 'undefined') {
    return { status: 'error', message: 'Columns for update  not fond' };
  }

  let linkedBudgetSourceIds = null;
  if (typeof linkedBudgetSourceIdsInput !== 'undefined') {
    try {
      linkedBudgetSourceIds = await resolveBudgetSourceIds(linkedBudgetSourceIdsInput);
      ensureHasLinkedBudgetSources(linkedBudgetSourceIds);
      await assertLinkedBudgetSourcesSchoolFinanceConsistent(linkedBudgetSourceIds);
    } catch (e) {
      return { status: 'error', message: e.message || String(e) };
    }
  }

  if (Array.isArray(linkedBudgetSourceIds)) {
    const currentRow = await db(tableName).where('id', id).first('refbankaccount');
    const nextBa = Object.prototype.hasOwnProperty.call(fliedData, 'refbankaccount')
      ? fliedData.refbankaccount
      : currentRow.refbankaccount;
    const nBa = nextBa != null && nextBa !== '' ? parseInt(String(nextBa), 10) : null;
    if (!Number.isInteger(nBa) || nBa <= 0) {
      const rows = await db('budgetsource')
        .whereIn('id', linkedBudgetSourceIds)
        .select('id', 'code', 'refbankaccount');
      const missing = rows.filter((r) => {
        const x = parseInt(String(r.refbankaccount ?? '').trim(), 10);
        return !Number.isInteger(x) || x <= 0;
      });
      if (missing.length > 0) {
        return {
          status: 'error',
          message: `แหล่งเงินต้องผูกบัญชีธนาคารให้ครบ (ยังไม่มีบัญชี: ${missing.map((m) => m.code || m.id).join(', ')}) หรือระบุ refbankaccount ที่หมวด (legacy)`,
        };
      }
    }
  }

  await db.transaction(async (trx) => {
    if (Object.keys(fliedData).length > 0) {
      await trx(tableName).where('id', '=', id).update(fliedData);
    }
    if (Array.isArray(linkedBudgetSourceIds)) {
      await replaceIncomeTypeBudgetSourceMap(trx, Number(id), linkedBudgetSourceIds);
    }
  });

  return {
    status: 'successfully',
    message: 'อัปเดตข้อมูลเรียบร้อยแล้ว',
    data: fliedData,
  };
}

async function remove(id, bodyData) {
  if (id === '' || typeof id === 'undefined') {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }
  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }
  const delResult = await db(tableName).where('id', '=', id).delete();
  if (delResult > 0) {
    return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อย' };
  }
  return {
    status: 'unsuccessful',
    message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ',
  };
}

async function getLinkedBudgetSources(id) {
  const incomeTypeId = Number(id);
  if (!Number.isInteger(incomeTypeId) || incomeTypeId <= 0) {
    return { status: 'error', message: 'id ข้อมูลไม่ถูกต้อง' };
  }
  const exists = await db(tableName).where('id', incomeTypeId).first();
  if (!exists) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }
  const rows = await db(mapTableName + ' as m')
    .leftJoin('budgetsource as b', 'b.id', 'm.refbudgetsource')
    .where('m.refincometype', incomeTypeId)
    .orderBy('b.code', 'asc')
    .select(
      'm.refbudgetsource as id',
      'b.code',
      'b.name',
      'b.fiscal_year',
      'b.budget_type',
      'b.refmoneygroup',
    );
  return {
    status: 'successfully',
    data: rows,
  };
}

async function replaceLinkedBudgetSources(id, bodyData) {
  const incomeTypeId = Number(id);
  if (!Number.isInteger(incomeTypeId) || incomeTypeId <= 0) {
    return { status: 'error', message: 'id ข้อมูลไม่ถูกต้อง' };
  }
  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }
  const exists = await db(tableName).where('id', incomeTypeId).first();
  if (!exists) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }
  let linkedBudgetSourceIds = [];
  try {
    linkedBudgetSourceIds = await resolveBudgetSourceIds(
      bodyData.linked_budget_source_ids ??
        bodyData.linkedBudgetSourceIds ??
        bodyData.ref_budget_source_ids ??
        bodyData.refBudgetSourceIds ??
        [],
    );
    ensureHasLinkedBudgetSources(linkedBudgetSourceIds);
    await assertLinkedBudgetSourcesSchoolFinanceConsistent(linkedBudgetSourceIds);
  } catch (e) {
    return {
      status: 'error',
      message: e.message || String(e),
    };
  }

  const currentRow = await db(tableName).where('id', incomeTypeId).first('refbankaccount');
  const nBa = currentRow?.refbankaccount != null && currentRow.refbankaccount !== ''
    ? parseInt(String(currentRow.refbankaccount), 10)
    : null;
  if (!Number.isInteger(nBa) || nBa <= 0) {
    const rows = await db('budgetsource')
      .whereIn('id', linkedBudgetSourceIds)
      .select('id', 'code', 'refbankaccount');
    const missing = rows.filter((r) => {
      const x = parseInt(String(r.refbankaccount ?? '').trim(), 10);
      return !Number.isInteger(x) || x <= 0;
    });
    if (missing.length > 0) {
      return {
        status: 'error',
        message: `แหล่งเงินต้องผูกบัญชีธนาคารให้ครบ (ยังไม่มีบัญชี: ${missing.map((m) => m.code || m.id).join(', ')}) หรือระบุ refbankaccount ที่หมวด (legacy)`,
      };
    }
  }

  await db.transaction(async (trx) => {
    await replaceIncomeTypeBudgetSourceMap(trx, incomeTypeId, linkedBudgetSourceIds);
  });
  return {
    status: 'successfully',
    message: 'อัปเดตความสัมพันธ์หมวดรายรับ-แหล่งเงินเรียบร้อย',
    data: {
      income_type_id: incomeTypeId,
      linked_budget_source_ids: linkedBudgetSourceIds,
    },
  };
}

module.exports = {
  getMultiple,
  create,
  update,
  remove,
  getLinkedBudgetSources,
  replaceLinkedBudgetSources,
}
