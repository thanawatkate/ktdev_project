/**
 * Mirrors local SQLite `usergroup_permission`: which permission keys each user group has.
 * FK to `usergroup` so deletes cascade. Backfills rows for groups whose nameen is admin/officer.
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
const ALL_PERMISSION_KEYS = [
  'nav.home',
  'nav.income',
  'nav.expense',
  'nav.loan',
  'nav.reports',
  'nav.usage_guide',
  'nav.logout',
  'approval.view',
  'approval.approve',
  'approval.reject',
  'budget_source.view',
  'budget_source.create',
  'budget_source.update',
  'budget_source.delete',
  'setting.view',
  'user_admin.view',
  'user_admin.create',
  'user_admin.reset_password',
  'user_admin.update_role',
  'user_admin.toggle_active',
  'audit_log.view',
  'menu.configure',
];

const OFFICER_PERMISSION_KEYS = [
  'nav.home',
  'nav.income',
  'nav.expense',
  'nav.loan',
  'nav.reports',
  'nav.usage_guide',
  'nav.logout',
  'budget_source.view',
];

exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('usergroup_permission');
  if (!hasTable) {
    await knex.schema.createTable('usergroup_permission', (table) => {
      table
        .integer('usergroup_id')
        .unsigned()
        .notNullable()
        .references('id')
        .inTable('usergroup')
        .onDelete('CASCADE')
        .onUpdate('CASCADE');
      table.string('permission_key', 128).notNullable();
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.primary(['usergroup_id', 'permission_key']);
    });
  }

  const groups = await knex('usergroup').select('id', 'nameen');
  for (const g of groups) {
    const name = String(g.nameen || '').toLowerCase();
    let keys = null;
    if (name === 'admin') keys = ALL_PERMISSION_KEYS;
    else if (name === 'officer') keys = OFFICER_PERMISSION_KEYS;
    if (!keys || !keys.length) continue;

    const rows = keys.map((permission_key) => ({
      usergroup_id: g.id,
      permission_key,
    }));
    const placeholders = rows.map(() => '(?, ?)').join(', ');
    const bindings = rows.flatMap((r) => [r.usergroup_id, r.permission_key]);
    await knex.raw(
      `INSERT IGNORE INTO usergroup_permission (usergroup_id, permission_key) VALUES ${placeholders}`,
      bindings,
    );
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
  return knex.schema.dropTableIfExists('usergroup_permission');
};
