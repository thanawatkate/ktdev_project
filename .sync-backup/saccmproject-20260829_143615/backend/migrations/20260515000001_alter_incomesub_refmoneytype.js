/**
 * บรรทัดย่อยรายรับต้องมีประเภทเงิน (moneytype) ต่อบรรทัด — ใช้รายงานคงเหลือ / pocket
 */
exports.up = async function (knex) {
  const has = await knex.schema.hasTable('incomesub');
  if (!has) return;
  const col = await knex.schema.hasColumn('incomesub', 'refmoneytype');
  if (!col) {
    await knex.schema.alterTable('incomesub', (t) => {
      t.integer('refmoneytype').unsigned().nullable()
        .references('id').inTable('moneytype')
        .onUpdate('CASCADE').onDelete('SET NULL')
        .comment('ประเภทเงินต่อบรรทัด (เงินสด/ฝากธนาคาร/สปช.)');
    });
  }
};

exports.down = async function (knex) {
  const has = await knex.schema.hasTable('incomesub');
  if (!has) return;
  if (await knex.schema.hasColumn('incomesub', 'refmoneytype')) {
    await knex.schema.alterTable('incomesub', (t) => {
      t.dropForeign(['refmoneytype']);
      t.dropColumn('refmoneytype');
    });
  }
};
