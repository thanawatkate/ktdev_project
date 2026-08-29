/**
 * หน้าหลัก / ตั้งค่า / ออกจากระบบ — ไม่เก็บใน app_menu (แอปฝังคงที่)
 * ลบแถวเดิมและหมวด "ภาพรวม" ที่เหลือว่าง
 */
exports.up = async function (knex) {
  if (!(await knex.schema.hasTable('app_menu'))) return;
  await knex('app_menu').whereIn('slug', ['home', 'setting', 'logout']).del();
  await knex('app_menu').where('slug', 'section_overview').del();
};

exports.down = async function () {
  // ไม่คืนแถว — seed เริ่มต้นอยู่ใน migration 20260503120000 สำหรับฐานใหม่ที่ยังไม่รันไฟล์นี้
};
