/**
 * วันที่ทางบัญชีของใบจ่าย — ใช้ docdate เมื่อมี (ตรงกับวันที่เอกสาร)
 * ไม่เช่นนั้นใช้ created (เวลาบันทึก) เพื่อ backward-compat
 *
 * ใช้ใน SQL เป็น fragment อ้างอิง alias ตาราง `e` = expense
 */
const EXPENSE_DOC_TS_SQL = 'COALESCE(e.docdate, e.created)';

/** เมื่อ query จากตาราง expense โดยไม่มี alias */
const EXPENSE_DOC_TS_BARE = 'COALESCE(docdate, created)';

module.exports = {
  EXPENSE_DOC_TS_SQL,
  EXPENSE_DOC_TS_BARE,
};
