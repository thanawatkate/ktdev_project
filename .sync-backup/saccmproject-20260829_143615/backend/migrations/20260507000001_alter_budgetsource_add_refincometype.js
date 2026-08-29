/**
 * เพิ่มความสัมพันธ์ 1:m ระหว่างหมวดรายรับ → แหล่งเงิน
 * budgetsource.refincometype (nullable) อ้างอิง incometype.id
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasColumn = await knex.schema.hasColumn('budgetsource', 'refincometype');
  if (!hasColumn) {
    await knex.schema.alterTable('budgetsource', (table) => {
      table
        .integer('refincometype')
        .unsigned()
        .nullable()
        .references('id')
        .inTable('incometype')
        .onUpdate('CASCADE')
        .onDelete('SET NULL')
        .comment('FK ไปหมวดรายรับ (nullable)');
      table.index(['refincometype'], 'idx_budgetsource_refincometype');
    });
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
  const hasColumn = await knex.schema.hasColumn('budgetsource', 'refincometype');
  if (hasColumn) {
    await knex.schema.alterTable('budgetsource', (table) => {
      table.dropIndex(['refincometype'], 'idx_budgetsource_refincometype');
      table.dropForeign(['refincometype']);
      table.dropColumn('refincometype');
    });
  }
};
