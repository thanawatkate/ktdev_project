/**
 * เพิ่ม column `pay_category` ใน expensesub สำหรับการแยกหมวดจ่ายในทะเบียนคุม
 * เงินอุดหนุนโครงการอาหารกลางวัน (ตามคู่มือหน้า 41):
 *   ลูกหนี้, ค่าตอบแทน, ค่าใช้สอย, ค่าวัสดุ
 *
 * เก็บเป็น string เพื่อให้ขยายเพิ่มได้ง่ายในอนาคต และไม่บังคับ FK
 */
exports.up = async function (knex) {
  const has = await knex.schema.hasColumn('expensesub', 'pay_category');
  if (!has) {
    await knex.schema.alterTable('expensesub', (t) => {
      t.string('pay_category', 32).nullable()
        .comment('หมวดจ่าย: debtor, compensation, expense, material (ใช้ในทะเบียนคุมอาหารกลางวัน)');
    });
  }
};

exports.down = async function (knex) {
  const has = await knex.schema.hasColumn('expensesub', 'pay_category');
  if (has) {
    await knex.schema.alterTable('expensesub', (t) => {
      t.dropColumn('pay_category');
    });
  }
};
