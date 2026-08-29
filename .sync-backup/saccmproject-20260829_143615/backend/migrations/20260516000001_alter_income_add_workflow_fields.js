/**
 * สอดคล้อง expense (20260510191000): doc_status, money_domain, approved_*, posted_at, change_reason
 * TEAM_RULES §11.4 — โดเมนการเงินและสถานะเอกสารบนหัวรายรับ
 */
exports.up = async function (knex) {
  const hasIncome = await knex.schema.hasTable('income');
  if (!hasIncome) return;

  const add = async (col, fn) => {
    if (!(await knex.schema.hasColumn('income', col))) {
      await knex.schema.alterTable('income', fn);
    }
  };

  await add('doc_status', (t) => {
    t.string('doc_status', 24).notNullable().defaultTo('posted');
  });
  await add('money_domain', (t) => {
    t.string('money_domain', 32).nullable();
  });
  await add('approved_by', (t) => {
    t.integer('approved_by').unsigned().nullable();
  });
  await add('approved_at', (t) => {
    t.timestamp('approved_at').nullable();
  });
  await add('posted_at', (t) => {
    t.timestamp('posted_at').nullable();
  });
  await add('change_reason', (t) => {
    t.string('change_reason', 255).nullable();
  });

  try {
    await knex('income')
      .where((qb) => {
        qb.whereNull('doc_status').orWhere('doc_status', '');
      })
      .update({ doc_status: 'posted' });
  } catch (_) {
    /* ignore */
  }

  try {
    await knex('income')
      .where('doc_status', 'posted')
      .whereNull('posted_at')
      .update({ posted_at: knex.fn.now() });
  } catch (_) {
    /* ignore */
  }
};

exports.down = async function (knex) {
  const hasIncome = await knex.schema.hasTable('income');
  if (!hasIncome) return;

  const drop = async (col) => {
    if (await knex.schema.hasColumn('income', col)) {
      await knex.schema.alterTable('income', (t) => t.dropColumn(col));
    }
  };

  await drop('change_reason');
  await drop('posted_at');
  await drop('approved_at');
  await drop('approved_by');
  await drop('money_domain');
  await drop('doc_status');
};
