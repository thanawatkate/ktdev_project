/**
 * คำสั่งแต่งตั้ง — ตามคู่มือการปฏิบัติงานการเงิน
 *   - แต่งตั้งเจ้าหน้าที่การเงินและเจ้าหน้าที่บัญชี
 *   - แต่งตั้งกรรมการเก็บรักษาเงิน
 *   - แต่งตั้งผู้ตรวจสอบรับจ่ายประจำวัน
 *
 * โครงสร้างชี้กรรมการได้หลายคนต่อ 1 คำสั่ง ผ่านตาราง appointment_order_member
 */
exports.up = async function (knex) {
  await knex.schema.createTable('appointment_order', function (t) {
    t.increments('id').primary();
    t.string('docno', 64).notNullable().comment('เลขที่คำสั่ง');
    t.timestamp('docdate').defaultTo(knex.fn.now()).comment('วันที่คำสั่ง');
    t.enu(
      'order_type',
      ['finance_officer', 'cash_committee', 'daily_inspector'],
      { useNative: true, existingType: false, enumName: 'appointment_order_type_enum' }
    ).notNullable().comment('ประเภทคำสั่ง');
    t.string('subject', 255).notNullable().comment('เรื่อง');
    t.text('content').nullable().comment('เนื้อหา/รายละเอียด');
    t.string('fiscal_year', 4).notNullable().comment('ปีงบประมาณ พ.ศ.');
    t.enu('status', ['active', 'cancelled'], {
      useNative: true,
      existingType: false,
      enumName: 'appointment_order_status_enum',
    }).notNullable().defaultTo('active');
    t.timestamp('created').defaultTo(knex.fn.now());
    t.timestamp('updated').defaultTo(knex.fn.now());
    t.unique(['docno', 'fiscal_year']);
  });

  await knex.schema.createTable('appointment_order_member', function (t) {
    t.increments('id').primary();
    t.integer('refappointment').unsigned().notNullable()
      .references('id').inTable('appointment_order')
      .onUpdate('CASCADE').onDelete('CASCADE');
    t.string('member_name', 255).notNullable().comment('ชื่อ-นามสกุล กรรมการ/เจ้าหน้าที่');
    t.string('member_position', 255).nullable().comment('ตำแหน่ง');
    t.enu('role_in_order', ['chair', 'committee', 'secretary', 'officer'], {
      useNative: true,
      existingType: false,
      enumName: 'appointment_order_role_enum',
    }).notNullable().defaultTo('committee');
    t.integer('sort').defaultTo(0);
    t.timestamp('created').defaultTo(knex.fn.now());
  });
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('appointment_order_member');
  await knex.schema.dropTableIfExists('appointment_order');
};
