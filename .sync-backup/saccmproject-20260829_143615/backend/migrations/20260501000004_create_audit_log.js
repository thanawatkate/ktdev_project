/**
 * Audit Trail — บันทึกทุกการเปลี่ยนแปลงข้อมูลในระบบ
 * ตามมาตรฐานการตรวจสอบภายในของหน่วยงานรัฐ
 */
exports.up = function (knex) {
  return knex.schema.createTable('audit_log', function (table) {
    table.increments('id').primary();
    table.string('tablename', 100).notNullable().comment('ชื่อตารางที่เปลี่ยนแปลง');
    table.integer('record_id').nullable().comment('id ของ record ที่เปลี่ยนแปลง');
    table.enu('action', ['INSERT', 'UPDATE', 'DELETE'], {
      useNative: true,
      existingType: false,
      enumName: 'audit_action_enum',
    }).notNullable();
    table.longtext('old_data').nullable().comment('ข้อมูลเดิม (JSON)');
    table.longtext('new_data').nullable().comment('ข้อมูลใหม่ (JSON)');
    table.integer('user_id').unsigned().nullable()
      .references('id').inTable('users')
      .onUpdate('CASCADE').onDelete('SET NULL');
    table.string('user_name', 255).nullable().comment('ชื่อผู้ใช้ (snapshot)');
    table.string('ip_address', 45).nullable().comment('IP Address ผู้ใช้');
    table.timestamp('created').defaultTo(knex.fn.now());

    // Index สำหรับการค้นหา
    table.index(['tablename', 'record_id'], 'idx_audit_table_record');
    table.index('created', 'idx_audit_created');
  });
};

exports.down = function (knex) {
  return knex.schema.dropTableIfExists('audit_log');
};
