const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { writeAuditLog } = require('../../sacc_auditlog/auditlog.service');

const tableName = 'party';

/** ใช้เทียบความซ้ำของเลขผู้เสียภาษี — ตรงกับฝั่ง Flutter `normalizePartyTaxIdForUniqueness` */
function normalizePartyTaxIdForUniqueness(v) {
  const s = (v || '').toString().trim();
  if (!s) return '';
  const digits = s.replace(/\D/g, '');
  if (digits.length > 0) return digits;
  return s.toLowerCase();
}

async function findPartyTaxIdDuplicateRow(taxRaw, excludeId) {
  const key = normalizePartyTaxIdForUniqueness(taxRaw);
  if (!key) return null;
  const rows = await db(tableName).select('id', 'name', 'taxid').whereNotNull('taxid');
  for (const r of rows) {
    const tid = r.taxid != null ? String(r.taxid).trim() : '';
    if (!tid) continue;
    if (excludeId != null && String(r.id) === String(excludeId)) continue;
    if (normalizePartyTaxIdForUniqueness(tid) === key) return r;
  }
  return null;
}

async function getMultiple(page = 1, query = {}) {
  const offset = helper.getOffset(page, config.listPerPage);
  const activeOnly = query.activeOnly !== 'false';
  const role = (query.role || '').toString().trim().toLowerCase();

  const builder = db(tableName)
    .orderBy('name', 'asc')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);

  if (activeOnly) {
    builder.where('isactive', true);
  }
  if (['payer', 'receiver', 'both'].includes(role)) {
    builder.where('role', role);
  }

  const rows = await builder;
  const data = helper.emptyOrRows(rows);
  const meta = { page, activeOnly, role: role || null };
  return { data, meta };
}

async function create(bodyData, meta = {}) {
  const name = (bodyData.name || '').toString().trim();
  const role = (bodyData.role || 'both').toString().trim().toLowerCase();

  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }
  if (!name) {
    return { status: 'error', message: 'name require ' };
  }
  if (!['payer', 'receiver', 'both'].includes(role)) {
    return { status: 'error', message: 'role require payer|receiver|both' };
  }

  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const existing = await db(tableName)
    .whereRaw('LOWER(name) = LOWER(?)', [name])
    .first();
  if (existing) {
    return {
      status: 'successfully',
      message: 'ข้อมูลมีอยู่แล้ว',
      lastid: existing.id,
    };
  }

  const taxDup = await findPartyTaxIdDuplicateRow(bodyData.taxid, null);
  if (taxDup) {
    return {
      status: 'error',
      message: `เลขผู้เสียภาษีซ้ำกับผู้เกี่ยวข้อง: ${(taxDup.name || '').toString().trim() || taxDup.id}`,
    };
  }

  const insertResult = await db(tableName).insert({
    name,
    role,
    phone: bodyData.phone || null,
    taxid: bodyData.taxid || null,
    remark: bodyData.remark || null,
    isactive: true,
  });
  const newId = Array.isArray(insertResult) ? insertResult[0] : insertResult;
  const numericId = newId != null && newId !== '' ? Number(newId) : 0;

  if (Number.isFinite(numericId) && numericId > 0) {
    await writeAuditLog({
      tablename: tableName,
      record_id: numericId,
      action: 'INSERT',
      new_data: JSON.stringify({
        name,
        role,
        phone: bodyData.phone || null,
        taxid: bodyData.taxid || null,
        remark: bodyData.remark || null,
        isactive: true,
      }),
      user_id: meta.userId,
      user_name: meta.userName,
      ip_address: meta.ip,
    });

    return {
      status: 'successfully',
      message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
      lastid: numericId,
    };
  }

  return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
}

async function update(id, bodyData, meta = {}) {
  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }
  if (id === '' || typeof id === 'undefined') {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const found = await db(tableName).where('id', '=', id).first();
  if (!found) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }

  const updateData = {};
  if (typeof bodyData.name !== 'undefined') updateData.name = bodyData.name || found.name;
  if (typeof bodyData.role !== 'undefined') updateData.role = bodyData.role || found.role;
  if (typeof bodyData.phone !== 'undefined') updateData.phone = bodyData.phone || null;
  if (typeof bodyData.taxid !== 'undefined') updateData.taxid = bodyData.taxid || null;
  if (typeof bodyData.remark !== 'undefined') updateData.remark = bodyData.remark || null;
  if (typeof bodyData.isactive !== 'undefined') updateData.isactive = !!bodyData.isactive;

  if (Object.keys(updateData).length === 0) {
    return { status: 'error', message: 'ไม่มีข้อมูลสำหรับอัปเดต' };
  }

  if (typeof bodyData.taxid !== 'undefined') {
    const taxDup = await findPartyTaxIdDuplicateRow(bodyData.taxid, id);
    if (taxDup) {
      return {
        status: 'error',
        message: `เลขผู้เสียภาษีซ้ำกับผู้เกี่ยวข้อง: ${(taxDup.name || '').toString().trim() || taxDup.id}`,
      };
    }
  }

  const result = await db(tableName).where('id', '=', id).update(updateData);

  const updated = await db(tableName).where('id', '=', id).first();
  await writeAuditLog({
    tablename: tableName,
    record_id: parseInt(id),
    action: 'UPDATE',
    old_data: JSON.stringify(found),
    new_data: JSON.stringify(updated || updateData),
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });

  return { status: 'successfully', message: result };
}

async function remove(id, bodyData, meta = {}) {
  if (bodyData.token === '' || typeof bodyData.token === 'undefined') {
    return { status: 'error', message: 'Token not found ' };
  }
  if (id === '' || typeof id === 'undefined') {
    return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp ' };
  }

  const found = await db(tableName).where('id', '=', id).first();
  if (!found) {
    return { status: 'successfully', message: 'ไม่พบข้อมูล (ลบไปแล้วหรือไม่มี)' };
  }

  await db(tableName).where('id', '=', id).del();

  await writeAuditLog({
    tablename: tableName,
    record_id: parseInt(id, 10),
    action: 'DELETE',
    old_data: JSON.stringify(found),
    new_data: null,
    user_id: meta.userId,
    user_name: meta.userName,
    ip_address: meta.ip,
  });

  return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อยแล้ว' };
}

module.exports = {
  getMultiple,
  create,
  update,
  remove,
};
