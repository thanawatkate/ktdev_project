/**
 * เพิ่มฟิลด์นำทางให้ mainmenu / submenu1 / submenu2
 * ใช้โครง mainmenu → submenu1 → submenu2 ตามสคีมาเดิมของโปรเจกต์
 */
exports.up = async function (knex) {
  const mainSort = await knex.schema.hasColumn('mainmenu', 'sort_order');
  if (!mainSort) {
    await knex.schema.alterTable('mainmenu', (table) => {
      table.integer('sort_order').unsigned().notNullable().defaultTo(0);
      table.string('icon_key', 64).nullable();
    });
  }

  const s1Route = await knex.schema.hasColumn('submenu1', 'route_key');
  if (!s1Route) {
    await knex.schema.alterTable('submenu1', (table) => {
      table.string('route_key', 64).nullable().comment('รหัสหน้าแอป เช่น home, income');
      table.string('required_permission', 128).nullable();
      table.string('icon_key', 64).nullable();
      table.integer('sort_order').unsigned().notNullable().defaultTo(0);
      table.integer('nav_index').unsigned().nullable().comment('ดัชนีแท็บหลักในแอป');
    });
  }

  const s2Route = await knex.schema.hasColumn('submenu2', 'route_key');
  if (!s2Route) {
    await knex.schema.alterTable('submenu2', (table) => {
      table.string('route_key', 64).nullable();
      table.string('required_permission', 128).nullable();
      table.string('icon_key', 64).nullable();
      table.integer('sort_order').unsigned().notNullable().defaultTo(0);
      table.integer('nav_index').unsigned().nullable();
    });
  }

  const row = await knex('mainmenu').count('* as cnt').first();
  const cnt = Number(row?.cnt ?? row?.['count(*)'] ?? 0);
  if (cnt > 0) return;

  await knex('mainmenu').insert([
    { id: 1, nameTH: 'ภาพรวม', nameEN: 'overview', use: 'Y', sort_order: 0, icon_key: null },
    { id: 2, nameTH: 'ธุรกรรม', nameEN: 'transactions', use: 'Y', sort_order: 1, icon_key: null },
    { id: 3, nameTH: 'การอนุมัติและรายงาน', nameEN: 'approval_reports', use: 'Y', sort_order: 2, icon_key: null },
    { id: 4, nameTH: 'ระบบ', nameEN: 'system', use: 'Y', sort_order: 3, icon_key: null },
  ]);

  await knex('submenu1').insert([
    { nameTH: 'หน้าหลัก', nameEN: 'home', refmainmenu: 1, use: 'Y', route_key: 'home', required_permission: 'nav.home', icon_key: 'home_rounded', sort_order: 0, nav_index: 0 },
    { nameTH: 'บันทึกรับเงิน', nameEN: 'income', refmainmenu: 2, use: 'Y', route_key: 'income', required_permission: 'nav.income', icon_key: 'south_rounded', sort_order: 0, nav_index: 1 },
    { nameTH: 'บันทึกเบิกเงิน', nameEN: 'expense', refmainmenu: 2, use: 'Y', route_key: 'expense', required_permission: 'nav.expense', icon_key: 'north_rounded', sort_order: 1, nav_index: 2 },
    { nameTH: 'บันทึกยืมเงิน', nameEN: 'loan', refmainmenu: 2, use: 'Y', route_key: 'loan', required_permission: 'nav.loan', icon_key: 'account_balance_rounded', sort_order: 2, nav_index: 3 },
    { nameTH: 'อนุมัติการเบิก', nameEN: 'approval', refmainmenu: 3, use: 'Y', route_key: 'approval', required_permission: 'approval.view', icon_key: 'task_alt_rounded', sort_order: 0, nav_index: 4 },
    { nameTH: 'รายงานการเงิน', nameEN: 'reports', refmainmenu: 3, use: 'Y', route_key: 'reports', required_permission: 'nav.reports', icon_key: 'bar_chart_rounded', sort_order: 1, nav_index: 5 },
    { nameTH: 'ตั้งค่าระบบ', nameEN: 'settings', refmainmenu: 4, use: 'Y', route_key: 'setting', required_permission: 'setting.view', icon_key: 'settings_rounded', sort_order: 0, nav_index: 6 },
    { nameTH: 'คู่มือใช้งาน', nameEN: 'usage_guide', refmainmenu: 4, use: 'Y', route_key: 'usage_guide', required_permission: 'nav.usage_guide', icon_key: 'menu_book_outlined', sort_order: 1, nav_index: 7 },
    { nameTH: 'ออกจากโปรแกรม', nameEN: 'logout', refmainmenu: 4, use: 'Y', route_key: 'logout', required_permission: 'nav.logout', icon_key: 'logout_rounded', sort_order: 99, nav_index: 8 },
  ]);
};

exports.down = async function (knex) {
  if (await knex.schema.hasColumn('submenu2', 'route_key')) {
    await knex.schema.alterTable('submenu2', (table) => {
      table.dropColumn('route_key');
      table.dropColumn('required_permission');
      table.dropColumn('icon_key');
      table.dropColumn('sort_order');
      table.dropColumn('nav_index');
    });
  }
  if (await knex.schema.hasColumn('submenu1', 'route_key')) {
    await knex.schema.alterTable('submenu1', (table) => {
      table.dropColumn('route_key');
      table.dropColumn('required_permission');
      table.dropColumn('icon_key');
      table.dropColumn('sort_order');
      table.dropColumn('nav_index');
    });
  }
  if (await knex.schema.hasColumn('mainmenu', 'sort_order')) {
    await knex.schema.alterTable('mainmenu', (table) => {
      table.dropColumn('sort_order');
      table.dropColumn('icon_key');
    });
  }
};
