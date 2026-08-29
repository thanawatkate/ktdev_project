/**
 * Seed ประเภทรายรับเริ่มต้นให้ตรงกับ SQLite `_seedIncomeTypes()`
 * ห้าม del() incometype — ตารางนี้มี OB-01..OB-13 และหมวดทะเบียนเงินประกัน/ภาษีร่วมอยู่ด้วย
 */
const INCOME_TYPES = [
  {
    code: '01',
    name: 'เงินอุดหนุนรายหัว',
    remark: 'เงินอุดหนุนค่าใช้จ่ายในการจัดการศึกษาขั้นพื้นฐาน จัดสรรตามจำนวนนักเรียน',
    sort: 1,
  },
  {
    code: '02',
    name: 'เงินอุดหนุนอาหารกลางวัน',
    remark: 'เงินอุดหนุนค่าอาหารกลางวันนักเรียน ระดับก่อนประถม–ประถมศึกษา',
    sort: 2,
  },
  {
    code: '03',
    name: 'เงินอุดหนุนอาหารเสริม (นม)',
    remark: 'เงินอุดหนุนโครงการอาหารเสริมนมโรงเรียน',
    sort: 3,
  },
  {
    code: '04',
    name: 'เงินอุดหนุนโครงการเรียนฟรี 15 ปี',
    remark: 'ค่าเล่าเรียน ค่าอุปกรณ์การเรียน ค่าชุดนักเรียน ค่ากิจกรรมพัฒนาคุณภาพ',
    sort: 4,
  },
  {
    code: '05',
    name: 'เงินอุดหนุนเฉพาะกิจ/โครงการพิเศษ',
    remark: 'เงินอุดหนุนจากหน่วยงานต้นสังกัดหรือภายนอกสำหรับโครงการเฉพาะ',
    sort: 5,
  },
  {
    code: '06',
    name: 'เงินบริจาคและทรัพย์สิน',
    remark: 'เงินหรือทรัพย์สินที่ได้รับบริจาคจากผู้ปกครอง ชุมชน หรือองค์กรภายนอก',
    sort: 6,
  },
  {
    code: '07',
    name: 'เงินรายได้สถานศึกษา',
    remark: 'รายได้จากการให้บริการ ค่าเช่าพื้นที่ ขายสินค้า กิจกรรมหารายได้',
    sort: 7,
  },
  {
    code: '08',
    name: 'เงินสมทบจากองค์กรปกครองส่วนท้องถิ่น',
    remark: 'เงินสนับสนุนจาก อบต. อบจ. เทศบาล หรือหน่วยงานท้องถิ่น',
    sort: 8,
  },
  {
    code: '09',
    name: 'เงินกู้ยืมเพื่อการศึกษา (กยศ./กรอ.)',
    remark: 'เงินกู้ยืมที่นักเรียน/นักศึกษาได้รับผ่านกองทุน กยศ. หรือ กรอ.',
    sort: 9,
  },
  {
    code: '10',
    name: 'รายรับอื่น',
    remark: 'รายรับที่ไม่จัดอยู่ในประเภทข้างต้น',
    sort: 10,
  },
];

exports.seed = async function (knex) {
  const hasCode = await knex.schema.hasColumn('incometype', 'code');
  for (const row of INCOME_TYPES) {
    const existing = hasCode
      ? await knex('incometype').where({ code: row.code }).first()
      : await knex('incometype').where({ name: row.name }).first();
    if (existing) {
      await knex('incometype')
        .where({ id: existing.id })
        .update({
          name: row.name,
          remark: row.remark,
          sort: row.sort,
          use: 'Y',
          ...(hasCode ? { code: row.code } : {}),
        });
      continue;
    }
    await knex('incometype').insert({
      ...(hasCode ? { code: row.code } : {}),
      name: row.name,
      remark: row.remark,
      sort: row.sort,
      use: 'Y',
    });
  }
};
