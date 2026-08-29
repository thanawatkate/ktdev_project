/**
 * ผูกทะเบียนเงินประกัน/ภาษีหัก ณ ที่จ่าย กับใบรับเงิน/ใบจ่าย
 * เพื่อให้รายงานหน้า 34 (contract_deposit / withholding_tax) สอดคล้องทะเบียนหน้า 42
 */
exports.up = async function (knex) {
  const hasIncome = await knex.schema.hasColumn('deposit_guarantee', 'ref_income_id');
  if (!hasIncome) {
    await knex.schema.alterTable('deposit_guarantee', (t) => {
      t.integer('ref_income_id')
        .unsigned()
        .nullable()
        .references('id')
        .inTable('income')
        .onUpdate('CASCADE')
        .onDelete('SET NULL')
        .comment('ใบรับเงินตอนรับประกัน/ภาษีหัก');
      t.integer('ref_expense_id')
        .unsigned()
        .nullable()
        .references('id')
        .inTable('expense')
        .onUpdate('CASCADE')
        .onDelete('SET NULL')
        .comment('ใบจ่ายตอนคืน/นำส่ง');
      t.index(['ref_income_id'], 'idx_deposit_ref_income');
      t.index(['ref_expense_id'], 'idx_deposit_ref_expense');
    });
  }
};

exports.down = async function (knex) {
  const hasIncome = await knex.schema.hasColumn('deposit_guarantee', 'ref_income_id');
  if (hasIncome) {
    await knex.schema.alterTable('deposit_guarantee', (t) => {
      t.dropIndex(['ref_income_id'], 'idx_deposit_ref_income');
      t.dropIndex(['ref_expense_id'], 'idx_deposit_ref_expense');
      t.dropForeign(['ref_income_id']);
      t.dropForeign(['ref_expense_id']);
      t.dropColumn('ref_income_id');
      t.dropColumn('ref_expense_id');
    });
  }
};
