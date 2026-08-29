/**
 * Seed แหล่งงบ GOV / NONGOV เริ่มต้น (ถ้ายังไม่มี) — อ้าง moneygroup id 5 / 2
 * ใช้ก่อน migration ที่อ้าง budgetsource.code = 'GOV' | 'NONGOV'
 *
 * @param { import("knex").Knex } knex
 */
exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('budgetsource');
  if (!hasTable) return;

  const fyCol = await knex.schema.hasColumn('budgetsource', 'fiscal_year');
  const fy = String(new Date().getFullYear() + 543);
  const hasMg = await knex.schema.hasColumn('budgetsource', 'refmoneygroup');

  const hasRefIncomeType = await knex.schema.hasColumn('budgetsource', 'refincometype');

  async function ensureRow(code, name, budgetType, refmoneygroup, refincometype = null) {
    const existing = await knex('budgetsource')
      .where({ code, use: 'Y' })
      .orderBy('id', 'asc')
      .first();
    if (existing) {
      const patch = { updated: knex.fn.now() };
      if (hasMg && refmoneygroup != null && existing.refmoneygroup == null) {
        patch.refmoneygroup = refmoneygroup;
      }
      if (hasRefIncomeType && refincometype && !existing.refincometype) {
        patch.refincometype = refincometype;
      }
      if (Object.keys(patch).length > 1) {
        await knex('budgetsource').where({ id: existing.id }).update(patch);
      }
      return;
    }
    const row = {
      code,
      name,
      description: '',
      budget_amount: 0,
      used_amount: 0,
      budget_type: budgetType,
      use: 'Y',
    };
    if (fyCol) row.fiscal_year = fy;
    if (hasMg) row.refmoneygroup = refmoneygroup;
    if (hasRefIncomeType && refincometype) row.refincometype = refincometype;
    await knex('budgetsource').insert(row);
  }

  await ensureRow('GOV', 'เงินงบประมาณ', 'งปม', 5);
  await ensureRow('NONGOV', 'เงินนอกงบประมาณ', 'นอกงปม', 2);

  if (await knex.schema.hasTable('incometype')) {
    const obRows = await knex('incometype')
      .select('id', 'code', 'name')
      .where('code', 'like', 'OB-%')
      .orderBy('sort', 'asc');
    for (const row of obRows) {
      await ensureRow(
        `NONGOV-${row.code}`,
        row.name || row.code,
        'นอกงปม',
        2,
        row.id,
      );
    }

    const guar = await knex('incometype').where({ code: 'GUAR-01' }).first();
    const wht = await knex('incometype').where({ code: 'WHT-01' }).first();
    await ensureRow('DEP-GUAR', 'เงินประกันสัญญา', 'นอกงปม', 4, guar?.id ?? null);
    await ensureRow('DEP-WHT', 'เงินภาษีหัก ณ ที่จ่าย', 'นอกงปม', 3, wht?.id ?? null);

    const hasIncomeRefMoneyGroup = await knex.schema.hasColumn('incometype', 'refmoneygroup');
    if (hasIncomeRefMoneyGroup) {
      await knex('incometype')
        .where('code', 'like', 'OB-%')
        .whereNull('refmoneygroup')
        .update({ refmoneygroup: 2 });
      if (guar) {
        await knex('incometype').where({ id: guar.id }).update({ refmoneygroup: 4 });
      }
      if (wht) {
        await knex('incometype').where({ id: wht.id }).update({ refmoneygroup: 3 });
      }
    }
  }
};

exports.down = async function () {
  // ไม่ลบแถว — อาจมี transaction ผูกอยู่แล้ว
};
