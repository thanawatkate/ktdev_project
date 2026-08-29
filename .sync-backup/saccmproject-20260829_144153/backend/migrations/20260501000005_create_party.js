/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
  return knex.schema.createTable('party', function (table) {
    table.increments('id').primary();
    table.timestamp('created').defaultTo(knex.fn.now());
    table.timestamp('updated').defaultTo(knex.fn.now());
    table.string('name', 255).notNullable();
    table.string('role', 20).notNullable().defaultTo('both');
    table.string('phone', 50).nullable();
    table.string('taxid', 50).nullable();
    table.string('remark', 255).nullable();
    table.boolean('isactive').notNullable().defaultTo(true);
    table.unique(['name', 'role']);
    table.index(['name']);
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
  return knex.schema.dropTableIfExists('party');
};
