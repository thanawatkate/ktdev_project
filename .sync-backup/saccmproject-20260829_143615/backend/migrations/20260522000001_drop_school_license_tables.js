/**
 * ย้าย license/registry ไป registry-backend — ลบตารางเดิมบน master DB
 */
exports.up = async function (knex) {
  const hasDevice = await knex.schema.hasTable('school_device');
  if (hasDevice) {
    await knex.schema.dropTable('school_device');
  }
  const hasLicense = await knex.schema.hasTable('school_license');
  if (hasLicense) {
    await knex.schema.dropTable('school_license');
  }
};

exports.down = async function (knex) {
  // ไม่สร้างกลับ — ใช้ registry-backend
};
