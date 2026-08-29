const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const { writeAuditLog } = require('../../sacc_auditlog/auditlog.service');

const TBL = 'receipt_book';
const ISSUE_TBL = 'receipt_issue';

function digitsOnly(s) {
  return String(s == null ? '' : s).replace(/\D/g, '');
}

function parseReceiptInt(s) {
  const d = digitsOnly(s);
  if (!d.length) return NaN;
  const n = parseInt(d, 10);
  return Number.isFinite(n) ? n : NaN;
}

function validateReceiptBookRange(startNo, endNo) {
  const startDigits = digitsOnly(startNo);
  const endDigits = digitsOnly(endNo);
  if (!startDigits.length || !endDigits.length) {
    return 'เลขที่เริ่มและเลขที่สุดท้ายต้องมีตัวเลข';
  }
  const start = parseReceiptInt(startNo);
  const end = parseReceiptInt(endNo);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start || endDigits.length < startDigits.length) {
    return 'เลขที่สุดท้ายต้องมากกว่าหรือเท่ากับเลขที่เริ่ม และมีจำนวนหลักเท่ากันหรือมากกว่า';
  }
  return null;
}

async function listBooks(page = 1, query = {}) {
  const offset = helper.getOffset(page, config.listPerPage);
  const builder = db(TBL).orderBy('fiscal_year', 'desc').orderBy('book_no', 'asc')
    .limit(config.listPerPage).offset(offset);
  if (query.fiscal_year) builder.where('fiscal_year', query.fiscal_year);
  if (query.status) builder.where('status', query.status);
  return { data: helper.emptyOrRows(await builder) };
}

async function createBook(body, meta = {}) {
  if (!body.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(body.token)) return { status: 'error', message: 'Token exp' };
  const required = ['book_no', 'start_no', 'end_no', 'fiscal_year'];
  for (const k of required) {
    if (!body[k]) return { status: 'error', message: `${k} require` };
  }

  const dup = await db(TBL).where({
    book_no: body.book_no,
    fiscal_year: body.fiscal_year,
    receipt_type: body.receipt_type || 'บร.',
  }).first();
  if (dup) return { status: 'error', message: 'มีเล่มนี้อยู่แล้วในปีงบประมาณ' };

  const rangeError = validateReceiptBookRange(body.start_no, body.end_no);
  if (rangeError) return { status: 'error', message: rangeError };

  const insertData = {
    book_no: body.book_no,
    receipt_type: body.receipt_type || 'บร.',
    start_no: body.start_no,
    end_no: body.end_no,
    fiscal_year: body.fiscal_year,
    status: body.status || 'available',
    received_from: body.received_from || null,
    remark: body.remark || null,
  };

  const r = await db(TBL).insert(insertData);
  const newId = Array.isArray(r) ? r[0] : r;
  await writeAuditLog({
    tablename: TBL, record_id: newId, action: 'INSERT',
    new_data: JSON.stringify(insertData),
    user_id: meta.userId, user_name: meta.userName, ip_address: meta.ip,
  });
  return { status: 'successfully', message: 'บันทึกข้อมูลเรียบร้อยแล้ว', lastid: newId };
}

async function issueReceipt(bookId, body, meta = {}) {
  if (!body.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(body.token)) return { status: 'error', message: 'Token exp' };
  if (!body.receipt_no) return { status: 'error', message: 'receipt_no require' };

  const book = await db(TBL).where('id', bookId).first();
  if (!book) return { status: 'error', message: 'ไม่พบเล่มใบเสร็จ' };

  const dup = await db('receipt_issue').where({ refbook: bookId, receipt_no: body.receipt_no }).first();
  if (dup) return { status: 'error', message: 'เลขที่ใบเสร็จซ้ำในเล่มนี้' };

  const nReceipt = parseReceiptInt(body.receipt_no);
  const nStart = parseReceiptInt(book.start_no);
  const nEnd = parseReceiptInt(book.end_no);
  if (Number.isNaN(nReceipt) || Number.isNaN(nStart) || Number.isNaN(nEnd)) {
    return { status: 'error', message: 'รูปแบบเลขที่ใบเสร็จไม่ถูกต้อง' };
  }
  if (nReceipt < nStart || nReceipt > nEnd) {
    return { status: 'error', message: 'เลขที่ใบเสร็จต้องอยู่ในช่วงที่กำหนดในเล่ม' };
  }

  const issues = await db('receipt_issue').where({ refbook: bookId }).select('receipt_no');
  let maxIssued = 0;
  for (const row of issues) {
    const n = parseReceiptInt(row.receipt_no);
    if (!Number.isNaN(n) && n > maxIssued) maxIssued = n;
  }
  const expected = maxIssued === 0 ? nStart : maxIssued + 1;
  if (nReceipt !== expected) {
    const w = Math.max(1, Math.min(12, Math.max(digitsOnly(body.receipt_no).length, digitsOnly(book.start_no).length)));
    const display = String(expected).padStart(w, '0');
    return {
      status: 'error',
      message: `เลขที่ใบเสร็จต้องเรียงต่อเนื่องจากใบก่อนหน้าในเล่มเดียวกัน (เลขที่ถัดไป: ${display})`,
    };
  }

  const insertData = {
    refbook: bookId,
    receipt_no: body.receipt_no,
    issued_at: body.issued_at || new Date(),
    issued_to: body.issued_to || null,
    amount: body.amount || 0,
    issue_status: body.issue_status || 'used',
    remark: body.remark || null,
    refincome: body.refincome || null,
  };

  const r = await db('receipt_issue').insert(insertData);
  const newId = Array.isArray(r) ? r[0] : r;

  await writeAuditLog({
    tablename: 'receipt_issue', record_id: newId, action: 'INSERT',
    new_data: JSON.stringify(insertData),
    user_id: meta.userId, user_name: meta.userName, ip_address: meta.ip,
  });

  return { status: 'successfully', message: 'บันทึกข้อมูลเรียบร้อยแล้ว', lastid: newId };
}

async function updateBook(id, body, meta = {}) {
  if (!body.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(body.token)) return { status: 'error', message: 'Token exp' };
  const found = await db(TBL).where('id', id).first();
  if (!found) return { status: 'error', message: 'ไม่พบข้อมูล' };

  const allow = ['book_no', 'receipt_type', 'start_no', 'end_no', 'fiscal_year', 'status', 'received_from', 'remark'];
  const update = {};
  for (const k of allow) if (typeof body[k] !== 'undefined') update[k] = body[k];

  if (!Object.keys(update).length) return { status: 'error', message: 'ไม่มีข้อมูลสำหรับอัปเดต' };

  const rangeError = validateReceiptBookRange(
    typeof update.start_no !== 'undefined' ? update.start_no : found.start_no,
    typeof update.end_no !== 'undefined' ? update.end_no : found.end_no,
  );
  if (rangeError) return { status: 'error', message: rangeError };

  await db(TBL).where('id', id).update({ ...update, updated: db.fn.now() });
  await writeAuditLog({
    tablename: TBL, record_id: parseInt(id, 10), action: 'UPDATE',
    old_data: JSON.stringify(found), new_data: JSON.stringify(update),
    user_id: meta.userId, user_name: meta.userName, ip_address: meta.ip,
  });
  return { status: 'successfully', message: 'อัปเดตข้อมูลเรียบร้อยแล้ว' };
}

async function removeBook(id, body, meta = {}) {
  if (!body.token) return { status: 'error', message: 'Token not found' };
  if (await checkTokenEXP(body.token)) return { status: 'error', message: 'Token exp' };
  const found = await db(TBL).where('id', id).first();
  if (!found) return { status: 'successfully', message: 'ไม่พบข้อมูล (ลบไปแล้วหรือไม่มี)' };
  const issueRow = await db(ISSUE_TBL).where('ref_book', id).count({ total: '*' }).first();
  const issueCount = parseInt(issueRow?.total || 0, 10);
  if ((parseInt(found.used_count || 0, 10) || 0) > 0 || issueCount > 0) {
    return { status: 'error', message: 'ลบเล่มใบเสร็จไม่ได้ เพราะมีการใช้ใบเสร็จแล้ว' };
  }
  await db(TBL).where('id', id).del();
  await writeAuditLog({
    tablename: TBL, record_id: parseInt(id, 10), action: 'DELETE',
    old_data: JSON.stringify(found),
    user_id: meta.userId, user_name: meta.userName, ip_address: meta.ip,
  });
  return { status: 'successfully', message: 'ลบข้อมูลเรียบร้อยแล้ว' };
}

module.exports = { listBooks, createBook, updateBook, removeBook, issueReceipt };
