/**
 * เมนูหลักของแอป (สอดคล้องกับ SQLite nav_menu_item ฝั่ง client)
 */
exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('nav_menu_item');
  if (exists) return;

  await knex.schema.createTable('nav_menu_item', function (table) {
    table.string('id', 64).primary();
    table.integer('nav_index').notNullable().unsigned().unique();
    table.string('section_title', 255).notNullable();
    table.integer('section_sort').notNullable().defaultTo(0);
    table.integer('item_sort').notNullable().defaultTo(0);
    table.string('label', 255).notNullable();
    table.string('icon_key', 64).notNullable();
    table.string('required_permission', 128).notNullable();
    table.boolean('is_active').notNullable().defaultTo(true);
    table.timestamp('lastModified').defaultTo(knex.fn.now());
  });

  const now = knex.fn.now();
  await knex('nav_menu_item').insert([
    {
      id: 'home',
      nav_index: 0,
      section_title: 'ภาพรวม',
      section_sort: 0,
      item_sort: 0,
      label: 'หน้าหลัก',
      icon_key: 'home_rounded',
      required_permission: 'nav.home',
      is_active: true,
      lastModified: now,
    },
    {
      id: 'income',
      nav_index: 1,
      section_title: 'ธุรกรรม',
      section_sort: 1,
      item_sort: 0,
      label: 'บันทึกรับเงิน',
      icon_key: 'south_rounded',
      required_permission: 'nav.income',
      is_active: true,
      lastModified: now,
    },
    {
      id: 'expense',
      nav_index: 2,
      section_title: 'ธุรกรรม',
      section_sort: 1,
      item_sort: 1,
      label: 'บันทึกเบิกเงิน',
      icon_key: 'north_rounded',
      required_permission: 'nav.expense',
      is_active: true,
      lastModified: now,
    },
    {
      id: 'loan',
      nav_index: 3,
      section_title: 'ธุรกรรม',
      section_sort: 1,
      item_sort: 2,
      label: 'บันทึกยืมเงิน',
      icon_key: 'account_balance_rounded',
      required_permission: 'nav.loan',
      is_active: true,
      lastModified: now,
    },
    {
      id: 'approval',
      nav_index: 4,
      section_title: 'การอนุมัติและรายงาน',
      section_sort: 2,
      item_sort: 0,
      label: 'อนุมัติการเบิก',
      icon_key: 'task_alt_rounded',
      required_permission: 'approval.view',
      is_active: true,
      lastModified: now,
    },
    {
      id: 'reports',
      nav_index: 5,
      section_title: 'การอนุมัติและรายงาน',
      section_sort: 2,
      item_sort: 1,
      label: 'รายงานการเงิน',
      icon_key: 'bar_chart_rounded',
      required_permission: 'nav.reports',
      is_active: true,
      lastModified: now,
    },
    {
      id: 'setting',
      nav_index: 6,
      section_title: 'ระบบ',
      section_sort: 3,
      item_sort: 0,
      label: 'ตั้งค่าระบบ',
      icon_key: 'settings_rounded',
      required_permission: 'setting.view',
      is_active: true,
      lastModified: now,
    },
    {
      id: 'usage_guide',
      nav_index: 7,
      section_title: 'ระบบ',
      section_sort: 3,
      item_sort: 1,
      label: 'คู่มือใช้งาน',
      icon_key: 'menu_book_outlined',
      required_permission: 'nav.usage_guide',
      is_active: true,
      lastModified: now,
    },
    {
      id: 'logout',
      nav_index: 8,
      section_title: '',
      section_sort: 999,
      item_sort: 0,
      label: 'ออกจากโปรแกรม',
      icon_key: 'logout_rounded',
      required_permission: 'nav.logout',
      is_active: true,
      lastModified: now,
    },
  ]);
};

exports.down = function (knex) {
  return knex.schema.dropTableIfExists('nav_menu_item');
};
