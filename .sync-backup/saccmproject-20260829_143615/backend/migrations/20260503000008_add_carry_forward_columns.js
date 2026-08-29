/**
 * ยกยอดมา: งบยกมา (budgetsource), ยอดบัญชีธนาคารยกมา (bankaccount), ยอดยืมคงค้างยกมา (loan)
 */
exports.up = async function (knex) {
  if (!(await knex.schema.hasColumn('budgetsource', 'brought_forward_amount'))) {
    await knex.schema.alterTable('budgetsource', (table) => {
      table
        .decimal('brought_forward_amount', 15, 2)
        .defaultTo(0)
        .comment('เงินงบยกมาจากปีก่อน');
    });
  }
  if (!(await knex.schema.hasColumn('bankaccount', 'opening_balance'))) {
    await knex.schema.alterTable('bankaccount', (table) => {
      table
        .decimal('opening_balance', 15, 2)
        .defaultTo(0)
        .comment('ยอดเงินในบัญชียกมา');
    });
  }
  if (!(await knex.schema.hasColumn('loan', 'opening_outstanding'))) {
    await knex.schema.alterTable('loan', (table) => {
      table
        .double('opening_outstanding')
        .defaultTo(0)
        .comment('ยอดคงค้างยืมยกมา');
    });
  }
};

exports.down = async function (knex) {
  if (await knex.schema.hasColumn('budgetsource', 'brought_forward_amount')) {
    await knex.schema.alterTable('budgetsource', (table) => {
      table.dropColumn('brought_forward_amount');
    });
  }
  if (await knex.schema.hasColumn('bankaccount', 'opening_balance')) {
    await knex.schema.alterTable('bankaccount', (table) => {
      table.dropColumn('opening_balance');
    });
  }
  if (await knex.schema.hasColumn('loan', 'opening_outstanding')) {
    await knex.schema.alterTable('loan', (table) => {
      table.dropColumn('opening_outstanding');
    });
  }
};
