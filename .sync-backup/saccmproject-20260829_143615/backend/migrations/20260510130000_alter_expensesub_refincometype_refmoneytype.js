/**
 * เพิ่มคอลัมน์สำหรับทะเบียนคุมและรายงานเงินคงเหลือ:
 *   - refincometype → หมวดเงินนอกงบประมาณ (OB-01..OB-13 / incometype)
 *   - refmoneytype → วิธีจ่าย (เงินสด / ฝากธนาคาร / ส่วนราชการผู้เบิก)
 *
 * หมายเหตุ: migration 20260506000002 เคยลบ refincometype ออก — คอลัมน์นี้กลับมาเป็น nullable
 * เพื่อให้รายจ่ายจากเงินนอกงบฯ ผูกกับทะเบียนคุมหน้า 40–41 ได้
 *
 * @param { import("knex").Knex } knex
 */
exports.up = async function (knex) {
  const hasIncometype = await knex.schema.hasColumn('expensesub', 'refincometype');
  if (!hasIncometype) {
    await knex.schema.table('expensesub', (t) => {
      t.integer('refincometype').unsigned().nullable()
        .references('id').inTable('incometype')
        .onUpdate('CASCADE').onDelete('SET NULL')
        .comment('หมวดเงินนอกงบฯ (incometype) สำหรับทะเบียนคุม');
    });
  }

  const hasMoneytype = await knex.schema.hasColumn('expensesub', 'refmoneytype');
  if (!hasMoneytype) {
    await knex.schema.table('expensesub', (t) => {
      t.integer('refmoneytype').unsigned().nullable()
        .references('id').inTable('moneytype')
        .onUpdate('CASCADE').onDelete('SET NULL')
        .comment('วิธีจ่าย/ช่องทางเงิน');
    });
  }
};

exports.down = async function (knex) {
  const hasMoneytype = await knex.schema.hasColumn('expensesub', 'refmoneytype');
  if (hasMoneytype) {
    await knex.schema.table('expensesub', (t) => {
      t.dropForeign(['refmoneytype']);
      t.dropColumn('refmoneytype');
    });
  }
  const hasIncometype = await knex.schema.hasColumn('expensesub', 'refincometype');
  if (hasIncometype) {
    await knex.schema.table('expensesub', (t) => {
      t.dropForeign(['refincometype']);
      t.dropColumn('refincometype');
    });
  }
};
