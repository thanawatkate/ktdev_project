/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasPayCheque = await knex.schema.hasTable('paycheque');
  if (!hasPayCheque) return;

  const hasClearedAt = await knex.schema.hasColumn('paycheque', 'cleared_at');
  if (!hasClearedAt) {
    await knex.schema.alterTable('paycheque', (table) => {
      table.timestamp('cleared_at').nullable();
    });
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
  const hasPayCheque = await knex.schema.hasTable('paycheque');
  if (!hasPayCheque) return;

  const hasClearedAt = await knex.schema.hasColumn('paycheque', 'cleared_at');
  if (hasClearedAt) {
    await knex.schema.alterTable('paycheque', (table) => {
      table.dropColumn('cleared_at');
    });
  }
};
