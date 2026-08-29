/**
 * แหล่งเงินเริ่มต้นต่อประเภทรายจ่าย — FK → budgetsource.id
 * สอดคล้อง SQLite `expense_type.refDefaultBudgetSource` → `budget_source_budget.id`
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasCol = await knex.schema.hasColumn('expensetype', 'refdefaultbudgetsource');
  if (hasCol) return;

  await knex.schema.alterTable('expensetype', (table) => {
    table
      .integer('refdefaultbudgetsource')
      .unsigned()
      .nullable()
      .comment('แหล่งเงินเริ่มต้นเมื่อบันทึกรายจ่าย (อ้างอิง budgetsource.id)')
      .references('id')
      .inTable('budgetsource')
      .onUpdate('CASCADE')
      .onDelete('SET NULL');
  });

  const anyBs = await knex('budgetsource').where('use', 'Y').orderBy('id', 'asc').first();
  if (!anyBs) return;

  const govBs = await knex('budgetsource').where({ code: 'GOV', use: 'Y' }).orderBy('id', 'asc').first();
  const nonGovBs = await knex('budgetsource').where({ code: 'NONGOV', use: 'Y' }).orderBy('id', 'asc').first();

  const govId = govBs?.id ?? anyBs.id;
  const nonGovId = nonGovBs?.id ?? anyBs.id;

  const govExpenseCodes = ['00', '04', '05', '06'];
  await knex('expensetype').whereIn('code', govExpenseCodes).update({ refdefaultbudgetsource: govId });
  await knex('expensetype').whereNotIn('code', govExpenseCodes).update({ refdefaultbudgetsource: nonGovId });

  await knex('expensetype').whereNull('refdefaultbudgetsource').update({ refdefaultbudgetsource: anyBs.id });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
  const hasCol = await knex.schema.hasColumn('expensetype', 'refdefaultbudgetsource');
  if (!hasCol) return;
  await knex.schema.alterTable('expensetype', (table) => {
    table.dropForeign(['refdefaultbudgetsource']);
    table.dropColumn('refdefaultbudgetsource');
  });
};
