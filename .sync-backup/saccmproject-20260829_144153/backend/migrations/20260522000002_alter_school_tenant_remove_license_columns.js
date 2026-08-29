/**
 * ลบคอลัมน์ที่ซ้ำกับ registry-backend (ถ้ามีจาก migration เก่า)
 */
exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('school_tenant');
  if (!hasTable) return;

  const hasExpires = await knex.schema.hasColumn('school_tenant', 'expires_at');
  if (hasExpires) {
    await knex.schema.alterTable('school_tenant', (t) => {
      t.dropColumn('expires_at');
    });
  }

  const hasKind = await knex.schema.hasColumn('school_tenant', 'license_kind');
  if (hasKind) {
    await knex.schema.alterTable('school_tenant', (t) => {
      t.dropColumn('license_kind');
    });
  }
};

exports.down = async function () {
  // ไม่คืนคอลัมน์ — ข้อมูล license อยู่ registry-backend
};
