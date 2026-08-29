/**
 * เพิ่ม column ใหม่ให้ตาราง expense และ expensereq:
 *   - refbudgetsource  FK → budgetsource
 *   - approval_status  สถานะการอนุมัติ
 *   - approved_by      FK → users
 *   - approved_at      วันที่อนุมัติ
 *   - reject_reason    เหตุผลที่ไม่อนุมัติ
 *   - detail           คำอธิบายการขอเบิก
 */
exports.up = async function (knex) {
  // ─── expensereq ──────────────────────────────────────────────────────────────
  await knex.schema.table('expensereq', function (table) {
    table.integer('refbudgetsource').unsigned().nullable()
      .references('id').inTable('budgetsource')
      .onUpdate('CASCADE').onDelete('SET NULL')
      .comment('อ้างอิงแหล่งเงินงบประมาณ');

    table.enu('approval_status',
      ['draft', 'pending', 'approved', 'rejected'],
      { useNative: true, existingType: false, enumName: 'approval_status_enum' }
    ).notNullable().defaultTo('draft').comment('สถานะการอนุมัติ');

    table.integer('approved_by').unsigned().nullable()
      .references('id').inTable('users')
      .onUpdate('CASCADE').onDelete('SET NULL')
      .comment('ผู้อนุมัติ');

    table.timestamp('approved_at').nullable().comment('วันที่อนุมัติ');
    table.string('reject_reason', 500).nullable().comment('เหตุผลที่ไม่อนุมัติ');
    table.text('detail').nullable().comment('คำอธิบายการขอเบิก');
    table.timestamp('docdate').defaultTo(knex.fn.now()).comment('วันที่เอกสาร');
  });

  // ─── expense ──────────────────────────────────────────────────────────────────
  await knex.schema.table('expense', function (table) {
    table.integer('refbudgetsource').unsigned().nullable()
      .references('id').inTable('budgetsource')
      .onUpdate('CASCADE').onDelete('SET NULL')
      .comment('อ้างอิงแหล่งเงินงบประมาณ');

    table.integer('refexpensereq').unsigned().nullable()
      .references('id').inTable('expensereq')
      .onUpdate('CASCADE').onDelete('SET NULL')
      .comment('อ้างอิงใบขอเบิก');

    table.text('detail').nullable().comment('คำอธิบายการเบิก');
  });

  // ─── income (add budget source) ───────────────────────────────────────────────
  await knex.schema.table('income', function (table) {
    table.integer('refbudgetsource').unsigned().nullable()
      .references('id').inTable('budgetsource')
      .onUpdate('CASCADE').onDelete('SET NULL')
      .comment('อ้างอิงแหล่งเงินงบประมาณ');
  });
};

exports.down = async function (knex) {
  await knex.schema.table('income', (t) => {
    t.dropColumn('refbudgetsource');
  });
  await knex.schema.table('expense', (t) => {
    t.dropColumn('refbudgetsource');
    t.dropColumn('refexpensereq');
    t.dropColumn('detail');
  });
  await knex.schema.table('expensereq', (t) => {
    t.dropColumn('refbudgetsource');
    t.dropColumn('approval_status');
    t.dropColumn('approved_by');
    t.dropColumn('approved_at');
    t.dropColumn('reject_reason');
    t.dropColumn('detail');
    t.dropColumn('docdate');
  });
};
