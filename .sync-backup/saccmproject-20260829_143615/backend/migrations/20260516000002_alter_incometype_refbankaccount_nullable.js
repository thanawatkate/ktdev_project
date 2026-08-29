/**
 * บัญชีธนาคารหลักระบุที่ budgetsource.refbankaccount
 * incometype.refbankaccount เป็น legacy / optional
 */
exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('incometype');
  if (!hasTable) return;

  const [fkRows] = await knex.raw(`
    SELECT tc.CONSTRAINT_NAME AS constraint_name
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.KEY_COLUMN_USAGE kcu
      ON tc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
     AND tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    WHERE tc.TABLE_SCHEMA = DATABASE()
      AND tc.TABLE_NAME = 'incometype'
      AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
      AND kcu.COLUMN_NAME = 'refbankaccount'
    LIMIT 1
  `);
  const fkName = fkRows && fkRows[0] && fkRows[0].constraint_name;
  if (fkName) {
    await knex.raw(`ALTER TABLE incometype DROP FOREIGN KEY \`${fkName}\``);
  }

  await knex.schema.alterTable('incometype', (t) => {
    t.integer('refbankaccount').unsigned().nullable().alter();
  });

  await knex.schema.alterTable('incometype', (t) => {
    t.foreign('refbankaccount')
      .references('id')
      .inTable('bankaccount')
      .onUpdate('CASCADE')
      .onDelete('SET NULL');
  });
};

exports.down = async function (knex) {
  const hasTable = await knex.schema.hasTable('incometype');
  if (!hasTable) return;

  const [fkRows] = await knex.raw(`
    SELECT tc.CONSTRAINT_NAME AS constraint_name
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.KEY_COLUMN_USAGE kcu
      ON tc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
     AND tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    WHERE tc.TABLE_SCHEMA = DATABASE()
      AND tc.TABLE_NAME = 'incometype'
      AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
      AND kcu.COLUMN_NAME = 'refbankaccount'
    LIMIT 1
  `);
  const fkName = fkRows && fkRows[0] && fkRows[0].constraint_name;
  if (fkName) {
    await knex.raw(`ALTER TABLE incometype DROP FOREIGN KEY \`${fkName}\``);
  }

  const nullCountRow = await knex('incometype').whereNull('refbankaccount').count({ c: '*' }).first();
  const nullRows = Number(nullCountRow?.c ?? 0);
  if (nullRows > 0) {
    throw new Error('rollback blocked: incometype.refbankaccount has NULL rows; fill legacy bank ids first');
  }

  await knex.schema.alterTable('incometype', (t) => {
    t.integer('refbankaccount').unsigned().notNullable().alter();
  });

  await knex.schema.alterTable('incometype', (t) => {
    t.foreign('refbankaccount')
      .references('id')
      .inTable('bankaccount')
      .onUpdate('CASCADE')
      .onDelete('CASCADE');
  });
};
