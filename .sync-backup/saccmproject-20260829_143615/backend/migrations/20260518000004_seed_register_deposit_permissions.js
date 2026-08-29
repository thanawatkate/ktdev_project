/**
 * สิทธิ์ทะเบียนเงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย
 */
const DEPOSIT_PERMS = [
  'register.deposit.view',
  'register.deposit.create',
  'register.deposit.update',
  'register.deposit.settle',
  'register.deposit.delete',
];

const OFFICER_DEPOSIT_PERMS = ['register.deposit.view'];

exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('usergroup_permission');
  if (!hasTable) return;

  const groups = await knex('usergroup').select('id', 'nameen');
  for (const g of groups) {
    const name = String(g.nameen || '').toLowerCase();
    let keys = null;
    if (name === 'admin') keys = DEPOSIT_PERMS;
    else if (name === 'officer') keys = OFFICER_DEPOSIT_PERMS;
    if (!keys?.length) continue;

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

exports.down = async function (knex) {
  const hasTable = await knex.schema.hasTable('usergroup_permission');
  if (!hasTable) return;
  await knex('usergroup_permission').whereIn('permission_key', DEPOSIT_PERMS).del();
};
