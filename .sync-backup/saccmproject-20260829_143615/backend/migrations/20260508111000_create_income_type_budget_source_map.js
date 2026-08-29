/**
 * รองรับความสัมพันธ์ M:N ระหว่างหมวดรายรับ (incometype)
 * และแหล่งเงิน (budgetsource)
 *
 * ตารางใหม่: income_type_budget_source_map
 * - refincometype -> incometype.id
 * - refbudgetsource -> budgetsource.id
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('income_type_budget_source_map');
  if (!hasTable) {
    await knex.schema.createTable('income_type_budget_source_map', (table) => {
      table.increments('id').primary();
      table
        .integer('refincometype')
        .unsigned()
        .notNullable()
        .references('id')
        .inTable('incometype')
        .onUpdate('CASCADE')
        .onDelete('CASCADE');
      table
        .integer('refbudgetsource')
        .unsigned()
        .notNullable()
        .references('id')
        .inTable('budgetsource')
        .onUpdate('CASCADE')
        .onDelete('CASCADE');
      table.unique(['refincometype', 'refbudgetsource'], 'uq_it_bsrc');
      table.index(['refincometype'], 'idx_it_bsrc_refincometype');
      table.index(['refbudgetsource'], 'idx_it_bsrc_refbudgetsource');
    });
  }

  // Backfill จากคอลัมน์ legacy budgetsource.refincometype
  const hasLegacyColumn = await knex.schema.hasColumn('budgetsource', 'refincometype');
  if (hasLegacyColumn) {
    await knex.raw(`
      INSERT IGNORE INTO income_type_budget_source_map (refincometype, refbudgetsource)
      SELECT b.refincometype, b.id
      FROM budgetsource b
      INNER JOIN incometype i ON i.id = b.refincometype
      WHERE b.refincometype IS NOT NULL
    `);
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
  const hasTable = await knex.schema.hasTable('income_type_budget_source_map');
  if (hasTable) {
    await knex.schema.dropTable('income_type_budget_source_map');
  }
};

