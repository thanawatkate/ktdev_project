/**
 * ตารางเดียว app_menu — parent_id = ลำดับชั้น, คอลัมน์ snake_case
 * ย้ายจาก nav_menu_item (ถ้ามี) แล้วลบตารางเมนูเก่า mainmenu / submenu1–5 / nav_menu_item
 */
exports.up = async function (knex) {
  const hasAppMenu = await knex.schema.hasTable('app_menu');
  if (!hasAppMenu) {
    await knex.schema.createTable('app_menu', (table) => {
      table.increments('id').unsigned().primary();
      table
        .integer('parent_id')
        .unsigned()
        .nullable()
        .references('id')
        .inTable('app_menu')
        .onUpdate('CASCADE')
        .onDelete('CASCADE');
      table.string('slug', 64).notNullable().unique();
      table.string('name_th', 255).notNullable();
      table.string('name_en', 255).notNullable();
      table.string('route_key', 64).nullable();
      table.string('required_permission', 128).nullable();
      table.string('icon_key', 64).nullable();
      table.integer('sort_order').unsigned().notNullable().defaultTo(0);
      table.integer('nav_index').unsigned().nullable();
      table.boolean('is_active').notNullable().defaultTo(true);
      table.timestamp('last_modified').defaultTo(knex.fn.now());
    });
  }

  let n = Number((await knex('app_menu').count('* as c').first())?.c ?? 0);
  if (n === 0 && (await knex.schema.hasTable('nav_menu_item'))) {
    const navRows = await knex('nav_menu_item')
      .select('*')
      .orderBy('section_sort', 'asc')
      .orderBy('item_sort', 'asc')
      .orderBy('nav_index', 'asc');
    if (navRows.length > 0) {
      await migrateNavRows(knex, navRows);
      n = Number((await knex('app_menu').count('* as c').first())?.c ?? 0);
    }
  }
  if (n === 0) {
    await seedDefaultMenu(knex);
  }

  if (await knex.schema.hasTable('nav_menu_item')) {
    await knex.schema.dropTableIfExists('nav_menu_item');
  }
  for (const t of ['submenu5', 'submenu4', 'submenu3', 'submenu2', 'submenu1', 'mainmenu']) {
    if (await knex.schema.hasTable(t)) {
      await knex.schema.dropTableIfExists(t);
    }
  }
};

/**
 * @param {import('knex').Knex} knex
 * @param {Record<string, unknown>[]} navRows
 */
async function migrateNavRows(knex, navRows) {
  const sectionSeen = new Map();
  for (const row of navRows) {
    const sk = `${row.section_sort}|${row.section_title ?? ''}`;
    if (!sectionSeen.has(sk)) {
      sectionSeen.set(sk, {
        section_sort: row.section_sort,
        section_title: row.section_title ?? '',
      });
    }
  }
  const sectionList = Array.from(sectionSeen.entries()).sort(
    (a, b) => (a[1].section_sort ?? 0) - (b[1].section_sort ?? 0)
  );
  const parentIdBySk = new Map();
  let idx = 0;
  for (const [sk, sec] of sectionList) {
    const slug = `section_${idx}_${sec.section_sort}`.slice(0, 64);
    const ins = await knex('app_menu').insert({
      parent_id: null,
      slug,
      name_th: sec.section_title || '—',
      name_en: `section_${sec.section_sort}`,
      route_key: null,
      required_permission: null,
      icon_key: null,
      sort_order: sec.section_sort ?? 0,
      nav_index: null,
      is_active: true,
      last_modified: knex.fn.now(),
    });
    const insertId = Array.isArray(ins) ? ins[0] : ins;
    parentIdBySk.set(sk, insertId);
    idx += 1;
  }

  const systemSk = Array.from(parentIdBySk.keys()).find(
    (k) => String(k).split('|')[1] === 'ระบบ'
  );

  for (const row of navRows) {
    const sk = `${row.section_sort}|${row.section_title ?? ''}`;
    let parentId = parentIdBySk.get(sk);
    const isLogout = row.nav_index === 8 || String(row.id) === 'logout';
    if (isLogout && systemSk) {
      parentId = parentIdBySk.get(systemSk);
    }
    if (parentId == null) continue;
    const leafSlug = String(row.id)
      .replace(/[^a-zA-Z0-9_]/g, '_')
      .slice(0, 64);
    await knex('app_menu').insert({
      parent_id: parentId,
      slug: leafSlug || `leaf_${row.nav_index}`,
      name_th: row.label,
      name_en: String(row.id),
      route_key: row.id,
      required_permission: row.required_permission,
      icon_key: row.icon_key,
      sort_order: row.item_sort ?? 0,
      nav_index: row.nav_index,
      is_active: row.is_active !== 0 && row.is_active !== false,
      last_modified: knex.fn.now(),
    });
  }
}

async function seedDefaultMenu(knex) {
  const now = knex.fn.now();
  // หน้าหลัก / ตั้งค่า / ออกจากระบบ ไม่เก็บใน app_menu (แอปฝังคงที่)
  await knex('app_menu').insert([
    { id: 1, parent_id: null, slug: 'section_transactions', name_th: 'ธุรกรรม', name_en: 'section_transactions', route_key: null, required_permission: null, icon_key: null, sort_order: 1, nav_index: null, is_active: true, last_modified: now },
    { id: 2, parent_id: 1, slug: 'income', name_th: 'บันทึกรับเงิน', name_en: 'income', route_key: 'income', required_permission: 'nav.income', icon_key: 'south_rounded', sort_order: 0, nav_index: 1, is_active: true, last_modified: now },
    { id: 3, parent_id: 1, slug: 'expense', name_th: 'บันทึกเบิกเงิน', name_en: 'expense', route_key: 'expense', required_permission: 'nav.expense', icon_key: 'north_rounded', sort_order: 1, nav_index: 2, is_active: true, last_modified: now },
    { id: 4, parent_id: 1, slug: 'loan', name_th: 'บันทึกยืมเงิน', name_en: 'loan', route_key: 'loan', required_permission: 'nav.loan', icon_key: 'account_balance_rounded', sort_order: 2, nav_index: 3, is_active: true, last_modified: now },
    { id: 5, parent_id: null, slug: 'section_approval_reports', name_th: 'การอนุมัติและรายงาน', name_en: 'section_approval_reports', route_key: null, required_permission: null, icon_key: null, sort_order: 2, nav_index: null, is_active: true, last_modified: now },
    { id: 6, parent_id: 5, slug: 'approval', name_th: 'อนุมัติการเบิก', name_en: 'approval', route_key: 'approval', required_permission: 'approval.view', icon_key: 'task_alt_rounded', sort_order: 0, nav_index: 4, is_active: true, last_modified: now },
    { id: 7, parent_id: 5, slug: 'reports', name_th: 'รายงานการเงิน', name_en: 'reports', route_key: 'reports', required_permission: 'nav.reports', icon_key: 'bar_chart_rounded', sort_order: 1, nav_index: 5, is_active: true, last_modified: now },
    { id: 8, parent_id: null, slug: 'section_system', name_th: 'ระบบ', name_en: 'section_system', route_key: null, required_permission: null, icon_key: null, sort_order: 3, nav_index: null, is_active: true, last_modified: now },
    { id: 9, parent_id: 8, slug: 'usage_guide', name_th: 'คู่มือใช้งาน', name_en: 'usage_guide', route_key: 'usage_guide', required_permission: 'nav.usage_guide', icon_key: 'menu_book_outlined', sort_order: 1, nav_index: 7, is_active: true, last_modified: now },
  ]);
  await knex.raw('ALTER TABLE app_menu AUTO_INCREMENT = 100');
}

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('app_menu');
};
