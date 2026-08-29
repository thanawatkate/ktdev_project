/**
 * เมนูหลัก "ข้อมูลพื้นฐานโรงเรียน" (nav_index 9) + สิทธิ์ nav.school_basics ให้กลุ่ม admin/officer
 */
exports.up = async function (knex) {
  if (await knex.schema.hasTable('app_menu')) {
    const exists = await knex('app_menu').where('slug', 'school_basics').first();
    if (!exists) {
      await knex('app_menu').insert({
        id: 10,
        parent_id: 8,
        slug: 'school_basics',
        name_th: 'ข้อมูลพื้นฐานโรงเรียน',
        name_en: 'school_basics',
        route_key: 'school_basics',
        required_permission: 'nav.school_basics',
        icon_key: 'school_rounded',
        sort_order: 0,
        nav_index: 9,
        is_active: true,
        last_modified: knex.fn.now(),
      });
    }
  }

  if (await knex.schema.hasTable('usergroup_permission')) {
    const groups = await knex('usergroup')
      .whereIn('nameen', ['admin', 'officer'])
      .select('id');
    for (const g of groups) {
      await knex.raw(
        'INSERT IGNORE INTO usergroup_permission (usergroup_id, permission_key) VALUES (?, ?)',
        [g.id, 'nav.school_basics'],
      );
    }
  }
};

exports.down = async function (knex) {
  if (await knex.schema.hasTable('usergroup_permission')) {
    await knex('usergroup_permission')
      .where('permission_key', 'nav.school_basics')
      .del();
  }
  if (await knex.schema.hasTable('app_menu')) {
    await knex('app_menu').where('slug', 'school_basics').del();
  }
};
