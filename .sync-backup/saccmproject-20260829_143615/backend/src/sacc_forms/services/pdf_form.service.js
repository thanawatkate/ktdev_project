const PDFDocument = require('pdfkit');
const path = require('path');
const fs = require('fs');
const db = require('../../configs/db.config');

/**
 * PDF generator สำหรับแบบฟอร์ม 4 แบบจาก docs/document-ref/FW (เอกสารแนบจัดซื้อ-จัดจ้าง)
 *   - receipt_substitute      : ใบรับรองแทนใบเสร็จรับเงิน (บก.111)
 *   - voucher_receive         : ใบสำคัญรับเงิน (บค.)
 *   - withholding_tax         : หนังสือรับรองการหักภาษี ณ ที่จ่าย
 *   - receipt_attachment      : ใบแนบใบเสร็จ
 *
 * รายงานเป็น PDF stream กลับไป (Content-Type application/pdf)
 *
 * หมายเหตุ: ใช้ฟอนต์ Sarabun ถ้ามีในเครื่อง (ผู้ใช้ปลายทางลง .ttf เอง)
 *           ถ้าไม่มีให้ fallback เป็น Helvetica และโชว์ภาษาไทยตาม unicode (อาจไม่สวย)
 */

const FONT_DIRS = [
  path.join(__dirname, '..', '..', '..', 'assets', 'fonts'),
  'C:\\Windows\\Fonts',
];

function findThaiFont() {
  const candidates = [
    'Sarabun-Regular.ttf', 'Sarabun.ttf',
    'THSarabunNew.ttf', 'THSarabun.ttf',
    'tahoma.ttf', 'Tahoma.ttf',
  ];
  for (const dir of FONT_DIRS) {
    if (!fs.existsSync(dir)) continue;
    for (const f of candidates) {
      const p = path.join(dir, f);
      if (fs.existsSync(p)) return p;
    }
  }
  return null;
}

function findThaiBoldFont() {
  const candidates = [
    'Sarabun-Bold.ttf',
    'THSarabunNew Bold.ttf', 'THSarabunBold.ttf',
    'tahomabd.ttf', 'TahomaBold.ttf',
  ];
  for (const dir of FONT_DIRS) {
    if (!fs.existsSync(dir)) continue;
    for (const f of candidates) {
      const p = path.join(dir, f);
      if (fs.existsSync(p)) return p;
    }
  }
  return null;
}

function thaiBahtText(num) {
  // แปลง number เป็นข้อความบาท (full)
  // อิง algorithm มาตรฐาน
  const numbers = ['ศูนย์', 'หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า'];
  const places = ['', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน', 'ล้าน'];
  function readInt(intStr) {
    if (intStr === '0') return numbers[0];
    let result = '';
    let len = intStr.length;
    for (let i = 0; i < len; i += 1) {
      const ch = parseInt(intStr[i], 10);
      const place = len - i - 1;
      if (ch === 0) continue;
      let digitWord = numbers[ch];
      if (place === 1 && ch === 1) digitWord = '';
      if (place === 1 && ch === 2) digitWord = 'ยี่';
      if (place === 0 && ch === 1 && len > 1) digitWord = 'เอ็ด';
      result += digitWord + (places[place] || '');
    }
    return result;
  }
  const fixed = (Math.round(num * 100) / 100).toFixed(2);
  const [intPart, decPart] = fixed.split('.');
  let txt = readInt(intPart) + 'บาท';
  if (decPart === '00') txt += 'ถ้วน';
  else txt += readInt(decPart) + 'สตางค์';
  return txt;
}

function thaiDateString(date) {
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return '';
  const months = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];
  return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear() + 543}`;
}

function buildPdfDoc() {
  const doc = new PDFDocument({ size: 'A4', margin: 56 });
  const thai = findThaiFont();
  const thaiBold = findThaiBoldFont();
  if (thai) doc.registerFont('Thai', thai);
  if (thaiBold) doc.registerFont('Thai-Bold', thaiBold);
  doc.font(thai ? 'Thai' : 'Helvetica');
  return { doc, hasThai: !!thai, hasThaiBold: !!thaiBold };
}

function setFont(doc, hasThai, hasThaiBold, bold = false) {
  if (bold && hasThaiBold) return doc.font('Thai-Bold');
  if (hasThai) return doc.font('Thai');
  return doc.font(bold ? 'Helvetica-Bold' : 'Helvetica');
}

async function getSchoolProfile() {
  // school_profile อาจไม่มีในฝั่ง server — fallback เป็น default
  try {
    const r = await db('school_profile').first();
    if (r) return r;
  } catch (_) {}
  return {
    school_name: 'โรงเรียน',
    school_address: '',
    school_phone: '',
  };
}

/**
 * 1) ใบรับรองแทนใบเสร็จรับเงิน — บก.111
 */
async function generateReceiptSubstitute(payload, res) {
  const { doc, hasThai, hasThaiBold } = buildPdfDoc();
  const school = await getSchoolProfile();

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="receipt-substitute-${Date.now()}.pdf"`);
  doc.pipe(res);

  setFont(doc, hasThai, hasThaiBold, true);
  doc.fontSize(20).text('ใบรับรองแทนใบเสร็จรับเงิน', { align: 'center' });
  doc.fontSize(14).text('แบบ บก. 111', { align: 'center' });
  doc.moveDown(1);

  setFont(doc, hasThai, hasThaiBold, false);
  doc.fontSize(14);
  doc.text(`ส่วนราชการ/หน่วยงาน: ${school.school_name || ''}`);
  doc.text(`วันที่: ${thaiDateString(payload.docdate || new Date())}`);
  doc.moveDown(0.5);

  doc.text('ข้าพเจ้า ' + (payload.payer_name || '......................................'));
  doc.text('ตำแหน่ง ' + (payload.payer_position || '......................................'));
  doc.text('ขอรับรองว่ารายจ่ายดังต่อไปนี้ ไม่อาจเรียกใบเสร็จรับเงินจากผู้รับได้');
  doc.moveDown(0.5);

  // Table-like list
  const lines = Array.isArray(payload.items) && payload.items.length
    ? payload.items
    : [{ detail: payload.detail || '', amount: payload.amount || 0 }];

  const tableY = doc.y;
  doc.rect(56, tableY, 483, 24).stroke();
  setFont(doc, hasThai, hasThaiBold, true);
  doc.text('ลำดับ', 60, tableY + 6, { width: 40, align: 'center' });
  doc.text('รายการ', 100, tableY + 6, { width: 300, align: 'center' });
  doc.text('จำนวนเงิน', 400, tableY + 6, { width: 130, align: 'center' });

  setFont(doc, hasThai, hasThaiBold, false);
  let y = tableY + 24;
  let total = 0;
  lines.forEach((it, idx) => {
    const amt = parseFloat(it.amount) || 0;
    total += amt;
    doc.rect(56, y, 483, 24).stroke();
    doc.text(String(idx + 1), 60, y + 6, { width: 40, align: 'center' });
    doc.text(it.detail || '', 100, y + 6, { width: 300 });
    doc.text(amt.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), 400, y + 6, { width: 130, align: 'right' });
    y += 24;
  });

  doc.rect(56, y, 483, 24).stroke();
  setFont(doc, hasThai, hasThaiBold, true);
  doc.text('รวม', 100, y + 6, { width: 300, align: 'right' });
  doc.text(
    total.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
    400, y + 6, { width: 130, align: 'right' },
  );
  doc.moveDown(2);

  setFont(doc, hasThai, hasThaiBold, false);
  doc.text(`(${thaiBahtText(total)})`, { align: 'center' });
  doc.moveDown(2);

  doc.text(`ลงชื่อ ........................................... ผู้รับรองการจ่ายเงิน`, { align: 'right' });
  doc.text(`(${payload.payer_name || ''})`, { align: 'right' });
  doc.text(`ตำแหน่ง ${payload.payer_position || ''}`, { align: 'right' });

  doc.end();
}

/**
 * 2) ใบสำคัญรับเงิน (บค.)
 */
async function generateVoucherReceive(payload, res) {
  const { doc, hasThai, hasThaiBold } = buildPdfDoc();
  const school = await getSchoolProfile();

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="voucher-receive-${Date.now()}.pdf"`);
  doc.pipe(res);

  setFont(doc, hasThai, hasThaiBold, true);
  doc.fontSize(20).text('ใบสำคัญรับเงิน', { align: 'center' });
  doc.fontSize(14).text('(บค.)', { align: 'center' });
  doc.moveDown(1);

  setFont(doc, hasThai, hasThaiBold, false);
  doc.fontSize(14);
  doc.text(`เลขที่: ${payload.docno || ''}`);
  doc.text(`วันที่: ${thaiDateString(payload.docdate || new Date())}`);
  doc.text(`สถานที่: ${school.school_name || ''}`);
  doc.moveDown(0.5);

  doc.text('ข้าพเจ้า ' + (payload.receiver_name || '......................................'));
  doc.text('อยู่บ้านเลขที่ ' + (payload.receiver_address || '......................................'));
  doc.text(`ได้รับเงินจาก ${school.school_name || ''}`);
  doc.text(`เป็นค่า ${payload.detail || ''}`);
  doc.moveDown(0.5);

  const amt = parseFloat(payload.amount) || 0;
  doc.text(`จำนวน ${amt.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} บาท`);
  setFont(doc, hasThai, hasThaiBold, true);
  doc.text(`(${thaiBahtText(amt)})`);
  setFont(doc, hasThai, hasThaiBold, false);
  doc.moveDown(2);

  doc.text(`ลงชื่อ ........................................... ผู้รับเงิน`, { align: 'right' });
  doc.text(`(${payload.receiver_name || ''})`, { align: 'right' });
  doc.moveDown(0.5);
  doc.text(`ลงชื่อ ........................................... ผู้จ่ายเงิน`, { align: 'right' });
  doc.text(`(${payload.payer_name || ''})`, { align: 'right' });

  doc.end();
}

/**
 * 3) หนังสือรับรองการหักภาษี ณ ที่จ่าย
 */
async function generateWithholdingTax(payload, res) {
  const { doc, hasThai, hasThaiBold } = buildPdfDoc();
  const school = await getSchoolProfile();

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="withholding-tax-${Date.now()}.pdf"`);
  doc.pipe(res);

  setFont(doc, hasThai, hasThaiBold, true);
  doc.fontSize(18).text('หนังสือรับรองการหักภาษี ณ ที่จ่าย', { align: 'center' });
  doc.fontSize(12).text('แบบ บก.28', { align: 'center' });
  doc.fontSize(12).text('ตามมาตรา 50 ทวิ แห่งประมวลรัษฎากร', { align: 'center' });
  doc.moveDown(1);

  setFont(doc, hasThai, hasThaiBold, false);
  doc.fontSize(12);
  doc.text(`ผู้มีหน้าที่หักภาษี: ${school.school_name || ''}`);
  doc.text(`เลขประจำตัวผู้เสียภาษี: ${school.taxid || '-'}`);
  doc.text(`ที่อยู่: ${school.school_address || ''}`);
  doc.moveDown(0.5);

  doc.text(`ผู้ถูกหักภาษี: ${payload.payee_name || ''}`);
  doc.text(`เลขประจำตัวผู้เสียภาษี: ${payload.payee_taxid || ''}`);
  doc.text(`ที่อยู่: ${payload.payee_address || ''}`);
  doc.moveDown(1);

  // Table
  const tableY = doc.y;
  doc.rect(56, tableY, 483, 24).stroke();
  setFont(doc, hasThai, hasThaiBold, true);
  doc.text('ประเภทเงินได้', 60, tableY + 6, { width: 220 });
  doc.text('จำนวนเงินที่จ่าย', 280, tableY + 6, { width: 120, align: 'right' });
  doc.text('ภาษีหัก ณ ที่จ่าย', 400, tableY + 6, { width: 130, align: 'right' });

  setFont(doc, hasThai, hasThaiBold, false);
  let y = tableY + 24;
  doc.rect(56, y, 483, 24).stroke();
  const grossAmt = parseFloat(payload.gross_amount) || 0;
  const taxAmt = parseFloat(payload.tax_amount) || 0;
  doc.text(payload.income_kind || '', 60, y + 6, { width: 220 });
  doc.text(grossAmt.toLocaleString('en-US', { minimumFractionDigits: 2 }), 280, y + 6, { width: 120, align: 'right' });
  doc.text(taxAmt.toLocaleString('en-US', { minimumFractionDigits: 2 }), 400, y + 6, { width: 130, align: 'right' });

  y += 24;
  doc.rect(56, y, 483, 24).stroke();
  setFont(doc, hasThai, hasThaiBold, true);
  doc.text('รวม', 60, y + 6, { width: 220, align: 'right' });
  doc.text(grossAmt.toLocaleString('en-US', { minimumFractionDigits: 2 }), 280, y + 6, { width: 120, align: 'right' });
  doc.text(taxAmt.toLocaleString('en-US', { minimumFractionDigits: 2 }), 400, y + 6, { width: 130, align: 'right' });

  doc.moveDown(3);
  setFont(doc, hasThai, hasThaiBold, false);
  doc.text(`วันที่จ่ายเงิน: ${thaiDateString(payload.docdate || new Date())}`);
  doc.text(`(ภาษีรวม ${thaiBahtText(taxAmt)})`);
  doc.moveDown(2);

  doc.text(`ลงชื่อ ........................................... ผู้จ่ายเงิน/ผู้หักภาษี`, { align: 'right' });
  doc.text(`(${payload.signer_name || ''})`, { align: 'right' });

  doc.end();
}

/**
 * 4) ใบแนบใบเสร็จ
 */
async function generateReceiptAttachment(payload, res) {
  const { doc, hasThai, hasThaiBold } = buildPdfDoc();
  const school = await getSchoolProfile();

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="receipt-attachment-${Date.now()}.pdf"`);
  doc.pipe(res);

  setFont(doc, hasThai, hasThaiBold, true);
  doc.fontSize(20).text('ใบแนบใบเสร็จ', { align: 'center' });
  doc.fontSize(14).text(school.school_name || '', { align: 'center' });
  doc.moveDown(1);

  setFont(doc, hasThai, hasThaiBold, false);
  doc.fontSize(13);
  doc.text(`เลขที่เอกสาร: ${payload.docno || ''}`);
  doc.text(`วันที่: ${thaiDateString(payload.docdate || new Date())}`);
  doc.text(`รายการ: ${payload.subject || ''}`);
  doc.moveDown(0.5);

  const items = Array.isArray(payload.items) && payload.items.length
    ? payload.items
    : [{ receipt_no: '-', detail: payload.detail || '-', amount: payload.amount || 0 }];

  const tableY = doc.y;
  doc.rect(56, tableY, 483, 24).stroke();
  setFont(doc, hasThai, hasThaiBold, true);
  doc.text('ลำดับ', 60, tableY + 6, { width: 40, align: 'center' });
  doc.text('เลขที่ใบเสร็จ', 100, tableY + 6, { width: 100, align: 'center' });
  doc.text('รายการ', 200, tableY + 6, { width: 200, align: 'center' });
  doc.text('จำนวนเงิน', 400, tableY + 6, { width: 130, align: 'center' });

  setFont(doc, hasThai, hasThaiBold, false);
  let y = tableY + 24;
  let total = 0;
  items.forEach((it, idx) => {
    const amt = parseFloat(it.amount) || 0;
    total += amt;
    doc.rect(56, y, 483, 24).stroke();
    doc.text(String(idx + 1), 60, y + 6, { width: 40, align: 'center' });
    doc.text(it.receipt_no || '', 100, y + 6, { width: 100 });
    doc.text(it.detail || '', 200, y + 6, { width: 200 });
    doc.text(amt.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), 400, y + 6, { width: 130, align: 'right' });
    y += 24;
  });

  doc.rect(56, y, 483, 24).stroke();
  setFont(doc, hasThai, hasThaiBold, true);
  doc.text('รวม', 200, y + 6, { width: 200, align: 'right' });
  doc.text(total.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), 400, y + 6, { width: 130, align: 'right' });
  doc.moveDown(2);

  setFont(doc, hasThai, hasThaiBold, false);
  doc.text(`(${thaiBahtText(total)})`, { align: 'center' });
  doc.moveDown(3);

  doc.text(`ลงชื่อ ........................................... ผู้จัดทำ`, { align: 'right' });
  doc.text(`(${payload.preparer_name || ''})`, { align: 'right' });

  doc.end();
}

const DEPOSIT_TYPE_LABEL = {
  contract_guarantee: 'เงินประกันสัญญา',
  withholding_tax: 'ภาษีหัก ณ ที่จ่าย',
  other: 'อื่น ๆ',
};

const DEPOSIT_STATUS_LABEL = {
  holding: 'ถือไว้',
  returned: 'คืนแล้ว',
  submitted: 'นำส่งแล้ว',
  forfeited: 'ริบ',
};

/**
 * ทะเบียนคุมเงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย (คู่มือหน้า 42)
 * body: { school_name, fiscal_year, deposit_type?, rows? }
 * ถ้าไม่ส่ง rows จะดึงจาก deposit_guarantee ตาม fiscal_year / deposit_type
 */
async function generateDepositRegister(payload, res) {
  const { doc, hasThai, hasThaiBold } = buildPdfDoc();

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    'inline; filename="deposit_register.pdf"',
  );
  doc.pipe(res);

  const schoolName = (payload.school_name || payload.schoolName || '').toString();
  const fiscalYear = (payload.fiscal_year || payload.fiscalYear || '').toString();
  const depositType = (payload.deposit_type || payload.depositType || '').toString();

  let rows = Array.isArray(payload.rows) ? payload.rows : null;
  if (!rows || !rows.length) {
    let q = db('deposit_guarantee as d')
      .leftJoin('party as p', 'd.refparty', 'p.id')
      .select(
        'd.docdate',
        'd.docno',
        'd.deposit_type',
        'd.amount',
        'd.contract_no',
        'd.due_date',
        'd.status',
        'd.party_name_snapshot',
        'p.name as party_name',
        'd.settled_docno',
      )
      .orderBy('d.docdate', 'desc')
      .orderBy('d.id', 'desc')
      .limit(300);
    if (fiscalYear) q = q.where('d.fiscal_year', fiscalYear);
    if (depositType) q = q.where('d.deposit_type', depositType);
    rows = await q;
  }

  setFont(doc, hasThai, hasThaiBold, true);
  doc.fontSize(16).text('ทะเบียนคุมเงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย', {
    align: 'center',
  });
  doc.moveDown(0.5);
  setFont(doc, hasThai, hasThaiBold, false);
  doc.fontSize(12);
  if (schoolName) doc.text(schoolName, { align: 'center' });
  if (fiscalYear) {
    doc.text(`ปีงบประมาณ พ.ศ. ${fiscalYear}`, { align: 'center' });
  }
  if (depositType) {
    doc.text(
      `ประเภท: ${DEPOSIT_TYPE_LABEL[depositType] || depositType}`,
      { align: 'center' },
    );
  }
  doc.moveDown(1);

  const cols = [
    { label: 'วันที่', w: 58 },
    { label: 'เลขที่', w: 62 },
    { label: 'ประเภท', w: 72 },
    { label: 'จำนวนเงิน', w: 68 },
    { label: 'คู่สัญญา', w: 90 },
    { label: 'กำหนดคืน', w: 58 },
    { label: 'สถานะ', w: 52 },
  ];
  let x = 56;
  const headerY = doc.y;
  setFont(doc, hasThai, hasThaiBold, true);
  doc.fontSize(9);
  for (const c of cols) {
    doc.text(c.label, x, headerY, { width: c.w });
    x += c.w;
  }
  doc.moveDown(0.8);
  setFont(doc, hasThai, hasThaiBold, false);

  let totalHolding = 0;
  for (const r of rows) {
    if (doc.y > 720) {
      doc.addPage();
    }
    const y = doc.y;
    x = 56;
    const party = r.party_name || r.party_name_snapshot || '-';
    const amt = parseFloat(r.amount) || 0;
    if (r.status === 'holding') totalHolding += amt;
    const cells = [
      thaiDateString(r.docdate),
      (r.docno || '').toString(),
      DEPOSIT_TYPE_LABEL[r.deposit_type] || r.deposit_type || '-',
      amt.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
      party.length > 28 ? `${party.slice(0, 26)}…` : party,
      r.due_date ? thaiDateString(r.due_date) : '-',
      DEPOSIT_STATUS_LABEL[r.status] || r.status || '-',
    ];
    let cx = 56;
    for (let i = 0; i < cols.length; i += 1) {
      doc.text(cells[i], cx, y, { width: cols[i].w, lineBreak: false });
      cx += cols[i].w;
    }
    doc.moveDown(0.9);
  }

  doc.moveDown(1);
  setFont(doc, hasThai, hasThaiBold, true);
  doc.text(
    `รวมยอดถือไว้ (holding): ${totalHolding.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} บาท`,
    { align: 'right' },
  );
  doc.moveDown(2);
  setFont(doc, hasThai, hasThaiBold, false);
  doc.text('ลงชื่อ ........................................... ผู้จัดทำ', {
    align: 'right',
  });

  doc.end();
}

async function generateLoanContract(payload, res) {
  const { doc, hasThai, hasThaiBold } = buildPdfDoc();
  const school = await getSchoolProfile();

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="loan-contract-${Date.now()}.pdf"`);
  doc.pipe(res);

  const amount = parseFloat(payload.amount) || 0;
  const borrower = payload.borrower_name || payload.borrowerName || '';
  const purpose = payload.purpose || payload.detail || '';
  const dueDate = payload.due_date || payload.dueDate || '';
  const docDate = payload.docdate || payload.doc_date || new Date();

  setFont(doc, hasThai, hasThaiBold, true);
  doc.fontSize(18).text('สัญญาการยืมเงิน', { align: 'center' });
  doc.moveDown(0.8);

  setFont(doc, hasThai, hasThaiBold, false);
  doc.fontSize(13);
  doc.text(`เขียนที่ ${school.school_name || ''}`, { align: 'right' });
  doc.text(`วันที่ ${thaiDateString(docDate)}`, { align: 'right' });
  doc.moveDown(1);

  doc.text(
    `ข้าพเจ้า ${borrower || '................................................'} ตำแหน่ง ${payload.borrower_position || '................................................'} ` +
      `สังกัด ${school.school_name || '................................................'} ขอทำสัญญายืมเงินจากทางราชการดังต่อไปนี้`,
    { align: 'left' },
  );
  doc.moveDown(0.8);
  doc.text(`จำนวนเงิน ${amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} บาท (${thaiBahtText(amount)})`);
  doc.text(`เพื่อใช้ในราชการ: ${purpose || '........................................................................................'}`);
  if (dueDate) doc.text(`กำหนดส่งใช้เงินยืมภายในวันที่ ${thaiDateString(dueDate)}`);
  doc.moveDown(0.8);
  doc.text(
    'ข้าพเจ้าสัญญาว่าจะนำหลักฐานการจ่ายเงินพร้อมเงินเหลือจ่าย (ถ้ามี) ส่งใช้ภายในกำหนด และยินยอมให้หักเงินเดือนหรือเงินอื่นใดที่พึงได้รับจากทางราชการได้ หากไม่ปฏิบัติตามสัญญานี้',
  );
  doc.moveDown(2);

  doc.text('ลงชื่อ ........................................... ผู้ยืมเงิน', { align: 'right' });
  doc.text(`(${borrower})`, { align: 'right' });
  doc.moveDown(1);
  doc.text('ลงชื่อ ........................................... ผู้อนุมัติ', { align: 'right' });
  doc.text(`(${payload.approver_name || ''})`, { align: 'right' });
  doc.moveDown(1.5);

  setFont(doc, hasThai, hasThaiBold, true);
  doc.text('บันทึกการรับเงิน', { align: 'left' });
  setFont(doc, hasThai, hasThaiBold, false);
  doc.text(`ได้รับเงินยืมจำนวน ${amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} บาท ไว้ถูกต้องแล้ว`);
  doc.moveDown(1.5);
  doc.text('ลงชื่อ ........................................... ผู้รับเงิน', { align: 'right' });
  doc.text(`(${borrower})`, { align: 'right' });

  doc.end();
}

module.exports = {
  generateReceiptSubstitute,
  generateVoucherReceive,
  generateWithholdingTax,
  generateReceiptAttachment,
  generateDepositRegister,
  generateLoanContract,
};
