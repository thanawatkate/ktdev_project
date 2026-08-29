/**
 * Ensure the posted expense can reference its source expense request.
 *
 * Older databases may already have expense.refexpensereq from the budget
 * workflow migration; this migration is intentionally idempotent.
 */
exports.up = async function (knex) {
  const hasExpense = await knex.schema.hasTable('expense');
  if (hasExpense && !(await knex.schema.hasColumn('expense', 'refexpensereq'))) {
    await knex.schema.alterTable('expense', (table) => {
      table
        .integer('refexpensereq')
        .unsigned()
        .nullable()
        .references('id')
        .inTable('expensereq')
        .onUpdate('CASCADE')
        .onDelete('SET NULL')
        .comment('อ้างอิงใบขอเบิกต้นทาง');
    });
  }

  const hasExpenseReq = await knex.schema.hasTable('expensereq');
  if (
    hasExpenseReq &&
    !(await knex.schema.hasColumn('expensereq', 'expense_recorded'))
  ) {
    await knex.schema.alterTable('expensereq', (table) => {
      table
        .boolean('expense_recorded')
        .notNullable()
        .defaultTo(false)
        .comment('บันทึกเบิกจริงแล้วหรือยัง');
    });
  }
};

exports.down = async function () {
  // No-op: these columns may be owned by earlier migrations in existing installs.
};
