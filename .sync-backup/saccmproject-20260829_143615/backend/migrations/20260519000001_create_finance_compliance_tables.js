/**
 * ปิดวัน (daily closing) + บันทึกเหตุผลงบเทียบยอดธนาคาร
 * อ้างอิง TEAM_RULES §11.5–11.7
 */
exports.up = async function up(knex) {
  if (!(await knex.schema.hasTable('daily_closing'))) {
    await knex.schema.createTable('daily_closing', (t) => {
      t.increments('id').primary();
      t.date('close_date').notNullable().unique();
      t.json('snapshot_json').notNullable();
      t.integer('closed_by').unsigned().nullable();
      t.timestamp('closed_at').notNullable().defaultTo(knex.fn.now());
      t.text('note').nullable();
      t.timestamp('created_at').defaultTo(knex.fn.now());
      t.timestamp('updated_at').defaultTo(knex.fn.now());
    });
  }

  if (!(await knex.schema.hasTable('bank_reconciliation_adjustment'))) {
    await knex.schema.createTable('bank_reconciliation_adjustment', (t) => {
      t.increments('id').primary();
      t.date('as_of_date').notNullable().index();
      t.integer('ref_bankaccount').unsigned().nullable();
      t.string('reason_code', 32).notNullable();
      t.decimal('amount', 15, 2).notNullable().defaultTo(0);
      t.text('note').nullable();
      t.integer('created_by').unsigned().nullable();
      t.timestamp('created_at').defaultTo(knex.fn.now());
    });
  }
};

exports.down = async function down(knex) {
  await knex.schema.dropTableIfExists('bank_reconciliation_adjustment');
  await knex.schema.dropTableIfExists('daily_closing');
};
