/**
 * สิทธิ์ menu.configure — จัดการลำดับ/ชื่อ/เปิดปิดเมนูหลักใน app_menu (เฉพาะกลุ่ม admin โดยค่าเริ่มต้น)
 */
exports.up = async function (knex) {
  if (!(await knex.schema.hasTable('usergroup_permission'))) return;
  const admins = await knex('usergroup').where('nameen', 'admin').select('id');
  for (const g of admins) {
    await knex.raw(
      'INSERT IGNORE INTO usergroup_permission (usergroup_id, permission_key) VALUES (?, ?)',
      [g.id, 'menu.configure'],
    );
  }
};

exports.down = async function (knex) {
  if (!(await knex.schema.hasTable('usergroup_permission'))) return;
  await knex('usergroup_permission').where('permission_key', 'menu.configure').del();
};
