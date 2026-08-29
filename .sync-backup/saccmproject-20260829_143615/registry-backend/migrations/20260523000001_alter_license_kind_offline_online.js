/**
 * แพ็กเกจขาย: offline | online (ทดลองใช้อยู่ในแอป)
 */
exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('school_license');
  if (!hasTable) return;

  await knex('school_license')
    .whereIn('license_kind', ['standard', 'trial'])
    .update({ license_kind: 'online' });

  await knex('license_issue_log')
    .whereIn('license_kind', ['standard', 'trial'])
    .update({ license_kind: 'online' });

  await knex.raw(`
    ALTER TABLE school_license
    MODIFY license_kind ENUM('offline','online') NOT NULL DEFAULT 'offline'
  `);
  await knex.raw(`
    ALTER TABLE license_issue_log
    MODIFY license_kind ENUM('offline','online') NOT NULL DEFAULT 'offline'
  `);
};

exports.down = async function () {
  // ไม่ย้อน enum
};
