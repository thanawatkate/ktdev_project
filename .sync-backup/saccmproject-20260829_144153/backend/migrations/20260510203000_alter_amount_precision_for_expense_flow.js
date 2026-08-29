/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasExpense = await knex.schema.hasTable('expense');
  if (hasExpense) {
    const hasAmount = await knex.schema.hasColumn('expense', 'amount');
    if (hasAmount) {
      await knex.raw('ALTER TABLE `expense` MODIFY COLUMN `amount` DECIMAL(15,2) NOT NULL DEFAULT 0.00');
    }
    const hasChequeAmount = await knex.schema.hasColumn('expense', 'chequeamount');
    if (hasChequeAmount) {
      await knex.raw('ALTER TABLE `expense` MODIFY COLUMN `chequeamount` DECIMAL(15,2) NOT NULL DEFAULT 0.00');
    }
    const hasBankAmount = await knex.schema.hasColumn('expense', 'bankamount');
    if (hasBankAmount) {
      await knex.raw('ALTER TABLE `expense` MODIFY COLUMN `bankamount` DECIMAL(15,2) NOT NULL DEFAULT 0.00');
    }
  }

  const hasExpenseSub = await knex.schema.hasTable('expensesub');
  if (hasExpenseSub) {
    const hasAmount = await knex.schema.hasColumn('expensesub', 'amount');
    if (hasAmount) {
      await knex.raw('ALTER TABLE `expensesub` MODIFY COLUMN `amount` DECIMAL(15,2) NOT NULL DEFAULT 0.00');
    }
  }

  const hasExpenseSubSnake = await knex.schema.hasTable('expense_sub');
  if (hasExpenseSubSnake) {
    const hasAmount = await knex.schema.hasColumn('expense_sub', 'amount');
    if (hasAmount) {
      await knex.raw('ALTER TABLE `expense_sub` MODIFY COLUMN `amount` DECIMAL(15,2) NOT NULL DEFAULT 0.00');
    }
  }

  const hasPayCheque = await knex.schema.hasTable('paycheque');
  if (hasPayCheque) {
    const hasAmount = await knex.schema.hasColumn('paycheque', 'chequeamount');
    if (hasAmount) {
      await knex.raw('ALTER TABLE `paycheque` MODIFY COLUMN `chequeamount` DECIMAL(15,2) NOT NULL DEFAULT 0.00');
    }
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function () {
  // no-op: avoid precision loss rollback on financial columns
};
