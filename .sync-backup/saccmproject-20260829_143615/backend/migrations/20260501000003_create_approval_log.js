/**
 * บันทึกประวัติการอนุมัติ/ปฏิเสธ (Approval Log)
 * ทุก action ในกระบวนการ Workflow จะถูกบันทึกที่นี่
 */
exports.up = function (knex) {
  return knex.schema.createTable('approval_log', function (table) {
    table.increments('id').primary();
    table.string('ref_table', 100).notNullable().comment('ชื่อตาราง: expensereq, expense');
    table.integer('ref_id').unsigned().notNullable().comment('id ของ record ที่ดำเนินการ');
    table.enu('action',
      ['submit', 'approve', 'reject', 'cancel', 'revise'],
      { useNative: true, existingType: false, enumName: 'approval_action_enum' }
    ).notNullable().comment('การกระทำ');
    table.integer('actor_id').unsigned().nullable()
      .references('id').inTable('users')
      .onUpdate('CASCADE').onDelete('SET NULL');
    table.string('actor_name', 255).nullable().comment('ชื่อผู้ดำเนินการ (snapshot)');
    table.text('note').nullable().comment('หมายเหตุ/เหตุผล');
    table.timestamp('created').defaultTo(knex.fn.now());
  });
};

exports.down = function (knex) {
  return knex.schema.dropTableIfExists('approval_log');
};
