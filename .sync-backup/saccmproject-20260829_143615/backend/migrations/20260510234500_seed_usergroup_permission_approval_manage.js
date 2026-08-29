/**
 * เพิ่ม permission `approval.manage` ให้กลุ่ม admin — ให้สอดคล้องกับ
 * `sacc_approval/services/approval.service.js` (hasApprovalPermission / hasRejectPermission)
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('usergroup_permission');
  if (!hasTable) return;

  const adminRows = await knex('usergroup')
    .whereRaw('LOWER(nameen) = ?', ['admin'])
    .select('id');
  if (!adminRows.length) return;

  const placeholders = adminRows.map(() => '(?, ?)').join(', ');
  const bindings = adminRows.flatMap((r) => [r.id, 'approval.manage']);
  await knex.raw(
    `INSERT IGNORE INTO usergroup_permission (usergroup_id, permission_key) VALUES ${placeholders}`,
    bindings,
  );
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
  const hasTable = await knex.schema.hasTable('usergroup_permission');
  if (!hasTable) return;

  const adminRows = await knex('usergroup')
    .whereRaw('LOWER(nameen) = ?', ['admin'])
    .select('id');
  for (const row of adminRows) {
    await knex('usergroup_permission')
      .where({ usergroup_id: row.id, permission_key: 'approval.manage' })
      .del();
  }
};
