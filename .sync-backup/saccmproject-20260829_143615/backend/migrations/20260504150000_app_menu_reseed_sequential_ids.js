/**
 * ฐานที่มี app_menu แบบ id เก่า (เช่น 3–12) — ลบแล้วแทรกชุด default id 1–9 ให้ตรง seed ปัจจุบัน
 * ฐานใหม่ที่ seed จาก 20260503120000 แล้วได้ id 1–9 อยู่แล้ว: migration นี้ยังรันได้ (idempotent)
 */
exports.up = async function (knex) {
  if (!(await knex.schema.hasTable('app_menu'))) return;
  const now = knex.fn.now();
  const rows = [
    { id: 1, parent_id: null, slug: 'section_transactions', name_th: 'ธุรกรรม', name_en: 'section_transactions', route_key: null, required_permission: null, icon_key: null, sort_order: 1, nav_index: null, is_active: true, last_modified: now },
    { id: 2, parent_id: 1, slug: 'income', name_th: 'บันทึกรับเงิน', name_en: 'income', route_key: 'income', required_permission: 'nav.income', icon_key: 'south_rounded', sort_order: 0, nav_index: 1, is_active: true, last_modified: now },
    { id: 3, parent_id: 1, slug: 'expense', name_th: 'บันทึกเบิกเงิน', name_en: 'expense', route_key: 'expense', required_permission: 'nav.expense', icon_key: 'north_rounded', sort_order: 1, nav_index: 2, is_active: true, last_modified: now },
    { id: 4, parent_id: 1, slug: 'loan', name_th: 'บันทึกยืมเงิน', name_en: 'loan', route_key: 'loan', required_permission: 'nav.loan', icon_key: 'account_balance_rounded', sort_order: 2, nav_index: 3, is_active: true, last_modified: now },
    { id: 5, parent_id: null, slug: 'section_approval_reports', name_th: 'การอนุมัติและรายงาน', name_en: 'section_approval_reports', route_key: null, required_permission: null, icon_key: null, sort_order: 2, nav_index: null, is_active: true, last_modified: now },
    { id: 6, parent_id: 5, slug: 'approval', name_th: 'อนุมัติการเบิก', name_en: 'approval', route_key: 'approval', required_permission: 'approval.view', icon_key: 'task_alt_rounded', sort_order: 0, nav_index: 4, is_active: true, last_modified: now },
    { id: 7, parent_id: 5, slug: 'reports', name_th: 'รายงานการเงิน', name_en: 'reports', route_key: 'reports', required_permission: 'nav.reports', icon_key: 'bar_chart_rounded', sort_order: 1, nav_index: 5, is_active: true, last_modified: now },
    { id: 8, parent_id: null, slug: 'section_system', name_th: 'ระบบ', name_en: 'section_system', route_key: null, required_permission: null, icon_key: null, sort_order: 3, nav_index: null, is_active: true, last_modified: now },
    { id: 9, parent_id: 8, slug: 'usage_guide', name_th: 'คู่มือใช้งาน', name_en: 'usage_guide', route_key: 'usage_guide', required_permission: 'nav.usage_guide', icon_key: 'menu_book_outlined', sort_order: 1, nav_index: 7, is_active: true, last_modified: now },
  ];
  await knex('app_menu').del();
  await knex('app_menu').insert(rows);
  await knex.raw('ALTER TABLE app_menu AUTO_INCREMENT = 100');
};

exports.down = async function () {};
