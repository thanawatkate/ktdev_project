/**
 * เมนู link tree: แยก「ใบขอเบิก」 + จัดหมวดธุรกรรมรับ-จ่าย (สอดคล้อง Flutter HomeNavIndex.expenseReq = 11)
 */
exports.up = async function (knex) {
  const now = knex.fn.now();
  const hasReq = await knex('app_menu').where({ slug: 'expense_req' }).first();
  if (!hasReq) {
    await knex('app_menu').insert({
      id: 13,
      parent_id: 1,
      slug: 'expense_req',
      name_th: 'ใบขอเบิก',
      name_en: 'expense_req',
      route_key: 'expense_req',
      required_permission: 'nav.expense_req',
      icon_key: 'request_quote_outlined',
      sort_order: 1,
      nav_index: 11,
      is_active: true,
      last_modified: now,
    });
  }
  await knex('app_menu').where({ slug: 'section_transactions' }).update({
    name_th: 'ธุรกรรมรับ-จ่าย',
    last_modified: now,
  });
  await knex('app_menu').where({ slug: 'section_approval_reports' }).update({
    name_th: 'การอนุมัติเบิกจ่าย',
    last_modified: now,
  });
  await knex('app_menu').where({ slug: 'expense' }).update({
    name_th: 'เบิกจริง (ใบสำคัญ)',
    sort_order: 2,
    last_modified: now,
  });
  await knex('app_menu').where({ slug: 'loan' }).update({ sort_order: 3, last_modified: now });

  const groups = await knex('usergroup').select('id');
  for (const g of groups) {
    const exists = await knex('usergroup_permission')
      .where({ usergroup_id: g.id, permission_key: 'nav.expense_req' })
      .first();
    if (!exists) {
      await knex('usergroup_permission').insert({
        usergroup_id: g.id,
        permission_key: 'nav.expense_req',
      });
    }
  }
};

exports.down = async function (knex) {
  await knex('usergroup_permission').where({ permission_key: 'nav.expense_req' }).del();
  await knex('app_menu').where({ slug: 'expense_req' }).del();
  await knex('app_menu').where({ slug: 'expense' }).update({
    name_th: 'บันทึกเบิกเงิน',
    sort_order: 1,
  });
  await knex('app_menu').where({ slug: 'loan' }).update({ sort_order: 2 });
};
