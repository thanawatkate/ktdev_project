/**
 * เพิ่ม budgetsource.refmoneygroup → FK ไปยัง moneygroup.id (nullable)
 *
 * "ประเภทเงิน" ตามระเบียบการคลัง 5 ประเภท:
 *   1. เงินรายได้แผ่นดิน
 *   2. เงินงบประมาณ
 *   3. เงินนอกงบประมาณ
 *   4. เงินภาษีหัก ณ ที่จ่าย
 *   5. เงินประกันสัญญา
 *
 * ใช้คู่กับคอลัมน์เดิม `budget_type` ได้ (budget_type เป็น free-text/enum,
 * refmoneygroup เป็น FK ที่จัดการได้จาก master moneygroup) — แนะนำใช้ refmoneygroup
 * เป็นแหล่งความจริง ส่วน budget_type จะคงไว้เพื่อความเข้ากันได้กับข้อมูลเดิม
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('budgetsource');
  if (!hasTable) return;

  const hasColumn = await knex.schema.hasColumn('budgetsource', 'refmoneygroup');
  if (hasColumn) return;

  await knex.schema.alterTable('budgetsource', (table) => {
    table
      .integer('refmoneygroup')
      .unsigned()
      .nullable()
      .references('id')
      .inTable('moneygroup')
      .onUpdate('CASCADE')
      .onDelete('SET NULL')
      .comment('FK ไปประเภทเงิน (moneygroup) — nullable');
    table.index(['refmoneygroup'], 'idx_budgetsource_refmoneygroup');
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
  const hasTable = await knex.schema.hasTable('budgetsource');
  if (!hasTable) return;

  const hasColumn = await knex.schema.hasColumn('budgetsource', 'refmoneygroup');
  if (!hasColumn) return;

  await knex.schema.alterTable('budgetsource', (table) => {
    table.dropIndex(['refmoneygroup'], 'idx_budgetsource_refmoneygroup');
    table.dropForeign(['refmoneygroup']);
    table.dropColumn('refmoneygroup');
  });
};
