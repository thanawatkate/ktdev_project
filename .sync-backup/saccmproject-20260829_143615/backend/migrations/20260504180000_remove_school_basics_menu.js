/**
 * ถอนเมนู school_basics และสิทธิ์ nav.school_basics — ข้อมูลพื้นฐานโรงเรียนใช้ที่เมนูตั้งค่าระบบเท่านั้น
 */
exports.up = async function (knex) {
  if (await knex.schema.hasTable('usergroup_permission')) {
    await knex('usergroup_permission')
      .where('permission_key', 'nav.school_basics')
      .del();
  }
  if (await knex.schema.hasTable('app_menu')) {
    await knex('app_menu').where('slug', 'school_basics').del();
  }
};

exports.down = async function () {
  // ไม่คืนแถว — รายละเอียดเดิมอยู่ใน migration 20260504170000 หากต้องการย้อนรันให้รัน down ของไฟล์นั้นก่อน
};
