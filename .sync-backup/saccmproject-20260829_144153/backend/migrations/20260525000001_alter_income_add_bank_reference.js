/**
 * Store bank statement / passbook reference text for income entries.
 * Useful for bank interest such as OB-10 and other transfer receipts.
 */
exports.up = async function (knex) {
  const hasIncome = await knex.schema.hasTable('income');
  if (!hasIncome) return;

  if (!(await knex.schema.hasColumn('income', 'bank_reference'))) {
    await knex.schema.alterTable('income', (table) => {
      table.string('bank_reference', 255).nullable();
    });
  }
};

exports.down = async function (knex) {
  const hasIncome = await knex.schema.hasTable('income');
  if (!hasIncome) return;

  if (await knex.schema.hasColumn('income', 'bank_reference')) {
    await knex.schema.alterTable('income', (table) => {
      table.dropColumn('bank_reference');
    });
  }
};
