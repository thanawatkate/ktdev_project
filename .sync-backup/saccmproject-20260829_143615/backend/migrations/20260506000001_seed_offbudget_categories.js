/**
 * Seed 13 ประเภทเงินนอกงบประมาณ ตามคู่มือการปฏิบัติงานการเงิน (สพป.ยะลา เขต 2)
 * จากโฟลเดอร์เอกสารอ้างอิง docs/document-ref/FE ทะเบียนคุมเงินนอกงบประมาณ/
 *
 * - เพิ่มเป็น `incometype` (ลำดับ 101..113) ถ้ายังไม่มีโค้ด
 * - เก็บความสัมพันธ์กับ `budgetsource` (รหัส NONGOV-XXX) สำหรับใช้เป็นแหล่งงบเริ่มต้น
 *   ในรายงานทะเบียนคุมเงินนอกงบประมาณ
 */
const OFFBUDGET_CATEGORIES = [
  { code: 'OB-01', name: 'ค่าจัดการเรียนการสอน', sort: 101 },
  { code: 'OB-02', name: 'ปัจจัยพื้นฐานนักเรียนยากจน', sort: 102 },
  { code: 'OB-03', name: 'ค่าหนังสือเรียน', sort: 103 },
  { code: 'OB-04', name: 'ค่าอุปกรณ์การเรียน', sort: 104 },
  { code: 'OB-05', name: 'ค่าเครื่องแบบนักเรียน', sort: 105 },
  { code: 'OB-06', name: 'ค่ากิจกรรมพัฒนาผู้เรียน', sort: 106 },
  { code: 'OB-07', name: 'เงินบำรุงลูกเสือ-เนตรนารี-ยุวกาชาด', sort: 107 },
  { code: 'OB-08', name: 'ค่าเครื่องแบบลูกเสือ-เนตรนารี', sort: 108 },
  { code: 'OB-09', name: 'เงินอุดหนุนโครงการอาหารกลางวัน', sort: 109 },
  { code: 'OB-10', name: 'เงินดอกผลกองทุนโครงการอาหารกลางวัน', sort: 110 },
  { code: 'OB-11', name: 'เงินกองทุนเพื่อความเสมอภาคทางการศึกษา (กสศ.)', sort: 111 },
  { code: 'OB-12', name: 'ดอกเบี้ยบัญชีเงินอุดหนุนอื่น', sort: 112 },
  { code: 'OB-13', name: 'ดอกเบี้ยบัญชีโครงการอาหารกลางวัน', sort: 113 },
];

exports.up = async function (knex) {
  // เพิ่ม code column ใน incometype ถ้ายังไม่มี (ใช้สำหรับชี้หมวดเงินนอกงบฯ มาตรฐาน)
  const hasCode = await knex.schema.hasColumn('incometype', 'code');
  if (!hasCode) {
    await knex.schema.alterTable('incometype', (t) => {
      t.string('code', 32).nullable().comment('รหัสหมวด (เช่น OB-01)');
    });
  }

  for (const c of OFFBUDGET_CATEGORIES) {
    const existsByCode = await knex('incometype').where('code', c.code).first();
    if (existsByCode) continue;
    const existsByName = await knex('incometype').where('name', c.name).first();
    if (existsByName) {
      await knex('incometype').where('id', existsByName.id).update({
        code: c.code,
        sort: c.sort,
      });
      continue;
    }
    await knex('incometype').insert({
      name: c.name,
      remark: 'เงินนอกงบประมาณ — ตามคู่มือ พ.ศ. 2544',
      sort: c.sort,
      code: c.code,
      use: 'Y',
    });
  }
};

exports.down = async function (knex) {
  // ลบเฉพาะรายการที่ seed มา (ไม่แตะแถวที่ user สร้าง)
  for (const c of OFFBUDGET_CATEGORIES) {
    await knex('incometype').where('code', c.code).del();
  }
};
