/**
 * เพิ่ม refbankaccount ที่ตาราง budgetsource
 *
 * แหล่งเงิน (budgetsource) ผูกกับบัญชีธนาคารที่รับ/จ่ายโดยตรง
 * ใช้เป็น default บัญชีสำหรับ income/expense ที่อ้างแหล่งเงินนี้
 * Priority chain:
 *   income/expense.refbankaccount (override ต่อเอกสาร)
 *     ↓ ถ้าไม่มี
 *   budgetsource.refbankaccount ← คอลัมน์นี้
 *     ↓ ถ้าไม่มี
 *   incometype.refbankaccount (legacy fallback)
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasCol = await knex.schema.hasColumn('budgetsource', 'refbankaccount');
  if (!hasCol) {
    await knex.schema.alterTable('budgetsource', (table) => {
      table
        .integer('refbankaccount')
        .unsigned()
        .nullable()
        .references('id')
        .inTable('bankaccount')
        .onUpdate('CASCADE')
        .onDelete('SET NULL')
        .comment('บัญชีธนาคารที่ผูกกับแหล่งเงินนี้ (ใช้เป็น default ต่อเอกสาร)');
    });
  }
};

exports.down = async function (knex) {
  const hasCol = await knex.schema.hasColumn('budgetsource', 'refbankaccount');
  if (hasCol) {
    await knex.schema.alterTable('budgetsource', (table) => {
      table.dropForeign(['refbankaccount']);
      table.dropColumn('refbankaccount');
    });
  }
};
