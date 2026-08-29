/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
  return knex.schema.alterTable('income', function (table) {
    table.integer('refparty')
      .unsigned()
      .nullable()
      .references('id')
      .inTable('party')
      .onUpdate('CASCADE')
      .onDelete('SET NULL');
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
  return knex.schema.alterTable('income', function (table) {
    table.dropColumn('refparty');
  });
};
