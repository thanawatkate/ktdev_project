const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { createInExpenseReqSub } = require('../../sacc_expensereqsub/controllers/expensereqsub.controller');
const tableName = 'expensereq'

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(tableName)
    .select('*')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);
  const data = helper.emptyOrRows(rows);
  const meta = { page };
  return {
    data,
    meta
  }
}

async function create(bodyData) {
  if (!bodyData.token) {
    return { status: 'error', message: 'Token not found' };
  }
  if (await checkTokenEXP(bodyData.token)) {
    return { status: 'error', message: 'Token exp' };
  }
  if (!bodyData.docno) {
    return { status: 'error', message: 'docno require' };
  }
  if (!bodyData.refmember) {
    return { status: 'error', message: 'refmember require' };
  }
  if (!bodyData.subdata) {
    return { status: 'error', message: 'subdata require' };
  }

  const remark = bodyData.remark || bodyData.detail || null;
  let subdata;
  try {
    subdata = JSON.parse(bodyData.subdata);
  } catch (_) {
    return { status: 'error', message: 'subdata ไม่ถูกต้อง' };
  }
  if (!Array.isArray(subdata) || subdata.length < 1) {
    return { status: 'error', message: 'subdata require' };
  }

  let amount = 0;
  for (const row of subdata) {
    amount += Number(row.amount) || 0;
  }

  const insertPayload = {
    docno: bodyData.docno,
    amount: amount.toFixed(2),
    remark,
    refmember: bodyData.refmember,
    approval_status: 'draft',
    detail: bodyData.detail || remark,
    docdate: bodyData.docdate ? new Date(bodyData.docdate) : new Date(),
  };
  if (bodyData.refbudgetsource) {
    insertPayload.refbudgetsource = parseInt(bodyData.refbudgetsource, 10) || null;
  }

  const [insertId] = await db(tableName).insert(insertPayload);
  if (!insertId) {
    return { status: 'error', message: 'บันทึกข้อมูลไม่สำเร็จ' };
  }

  const insertSub = await createInExpenseReqSub(insertId, bodyData.subdata);
  if (!insertSub) {
    return { status: 'error', message: 'บันทึกรายการย่อยไม่สำเร็จ' };
  }

  return {
    status: 'successfully',
    message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
    lastid: insertId,
  };
}
async function update(id, bodyData) {
  if (!bodyData.token) return { status: 'error', message: 'Token not found ' };
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp ' };

  const existing = await db(tableName).where('id', id).first();
  if (!existing) {
    return { status: 'error', message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...' };
  }
  if (existing.approval_status && existing.approval_status !== 'draft') {
    return { status: 'error', message: 'แก้ไขได้เฉพาะใบขอเบิกสถานะร่าง' };
  }

  const patch = {};
  if (typeof bodyData.docno !== 'undefined') patch.docno = bodyData.docno;
  if (typeof bodyData.detail !== 'undefined') patch.detail = bodyData.detail;
  if (typeof bodyData.remark !== 'undefined') patch.remark = bodyData.remark;
  if (typeof bodyData.refmember !== 'undefined') patch.refmember = bodyData.refmember;
  if (typeof bodyData.refbudgetsource !== 'undefined') {
    patch.refbudgetsource = parseInt(bodyData.refbudgetsource, 10) || null;
  }
  if (typeof bodyData.docdate !== 'undefined') {
    const d = new Date(bodyData.docdate);
    if (!Number.isNaN(d.getTime())) patch.docdate = d;
  }

  let subdata = null;
  if (typeof bodyData.subdata !== 'undefined') {
    try {
      subdata = JSON.parse(bodyData.subdata);
    } catch (_) {
      return { status: 'error', message: 'subdata ไม่ถูกต้อง' };
    }
    if (!Array.isArray(subdata) || subdata.length < 1) {
      return { status: 'error', message: 'subdata require' };
    }
    patch.amount = subdata.reduce((s, row) => s + (Number(row.amount) || 0), 0).toFixed(2);
  }
  patch.updated = db.fn.now();

  await db.transaction(async (trx) => {
    await trx(tableName).where('id', id).update(patch);
    if (subdata) {
      await trx('expensereqsub').where('refexpensereq', id).delete();
      for (const row of subdata) {
        await trx('expensereqsub').insert({
          refexpensereq: id,
          refincometype: row.refincometype,
          amount: row.amount,
          remark: row.remark || '',
        });
      }
    }
  });
  return { status: 'successfully', message: 'อัปเดตข้อมูลเรียบร้อยแล้ว' };
}

async function remove(id, bodyData) {
  if (!id) return { status: 'error', message: 'id ข้อมูลไม่ควรเป็นค่าว่าง' };
  if (!bodyData.token) return { status: 'error', message: 'Token not found ' };
  if (await checkTokenEXP(bodyData.token)) return { status: 'error', message: 'Token exp ' };

  const existing = await db(tableName).where('id', id).first();
  if (!existing && bodyData.docno) {
    const byDocNo = await db(tableName).where('docno', bodyData.docno).first();
    if (byDocNo) id = byDocNo.id;
  } else if (!existing) {
    return {
      status: 'unsuccessful',
      message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ',
    };
  }

  const row = await db(tableName).where('id', id).first();
  if (row?.approval_status && row.approval_status !== 'draft') {
    return { status: 'error', message: 'ลบได้เฉพาะใบขอเบิกสถานะร่าง' };
  }
  const result = await db(tableName).where('id', id).delete();
  if (result > 0) return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อย' };
  return {
    status: 'unsuccessful',
    message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ',
  };
}

module.exports = {
  getMultiple,
  create,
  update,
  remove
}
