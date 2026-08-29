/**
 * ลบตาราง fund_source / fund_ledger / ledger_entry ของโมดูล fund_ledger ที่ถูกตัดทิ้ง
 * โมดูลซ้ำซ้อนกับ budget_source + offbudget_register module ที่ใช้งานจริงในระบบ
 *
 * ปลอดภัยสำหรับ:
 *   - DB ที่เคยรัน migration 20260508000001..003 (จะลบตารางเดิม)
 *   - DB ใหม่ที่ไม่เคยมีตารางพวกนี้ (no-op เพราะ DROP TABLE IF EXISTS)
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  // ลำดับ drop ต้องเริ่มจาก child → parent (FK constraints)
  await knex.schema.dropTableIfExists('ledger_entry');
  await knex.schema.dropTableIfExists('fund_ledger');
  await knex.schema.dropTableIfExists('fund_source');

  // ลบ enum type ที่ ledger_entry สร้างไว้ (PostgreSQL เท่านั้น — MySQL/MariaDB ไม่มีผล)
  try {
    await knex.raw('DROP TYPE IF EXISTS tx_type_enum');
  } catch (_) {
    // ignore — engine ไม่รองรับ DROP TYPE
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (_knex) {
  // ไม่สร้างคืน — โมดูลถูกตัดออกถาวร ใช้ budget_source + offbudget_register แทน
};
