/**
 * แหล่งเงินตัวอย่างสำหรับทะเบียนเงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย
 * (รันซ้ำได้ — ข้ามถ้ามี code แล้วในปีงบเดียวกัน)
 */
function currentFiscalYearBE() {
  const d = new Date();
  const ce = d.getFullYear();
  const m = d.getMonth() + 1;
  const be = ce + 543;
  return m >= 10 ? be + 1 : be;
}

/** moneygroup ids 1-5 must exist (see seeds07_moneygroupData.js) before FK insert */
async function ensureMoneyGroups(knex) {
  const hasTable = await knex.schema.hasTable('moneygroup');
  if (!hasTable) return;

  const rows = [
    { id: 1, name: 'เงินรายได้แผ่นดิน', remark: '', sort: 1, use: 'Y' },
    { id: 2, name: 'เงินนอกงบประมาณ', remark: '', sort: 3, use: 'Y' },
    { id: 3, name: 'เงินภาษีหัก ณ ที่จ่าย', remark: '', sort: 4, use: 'Y' },
    { id: 4, name: 'เงินประกันสัญญา', remark: '', sort: 5, use: 'Y' },
    { id: 5, name: 'เงินงบประมาณ', remark: '', sort: 2, use: 'Y' },
  ];

  for (const row of rows) {
    const exists = await knex('moneygroup').where({ id: row.id }).first('id');
    if (!exists) {
      await knex('moneygroup').insert(row);
    }
  }
}

exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('budgetsource');
  if (!hasTable) return;

  await ensureMoneyGroups(knex);

  const fy = String(currentFiscalYearBE());
  let refBank = null;
  const ba = await knex('bankaccount').select('id').orderBy('id', 'asc').first();
  if (ba?.id) refBank = ba.id;

  const guarType = await knex('incometype').where('code', 'GUAR-01').first('id');
  const whtType = await knex('incometype').where('code', 'WHT-01').first('id');

  const templates = [
    {
      code: `DEP-GUAR-${fy}`,
      name: 'เงินประกันสัญญา (ทะเบียนคุม)',
      refmoneygroup: 4,
      refincometype: guarType?.id ?? null,
    },
    {
      code: `DEP-WHT-${fy}`,
      name: 'ภาษีหัก ณ ที่จ่าย (ทะเบียนคุม)',
      refmoneygroup: 3,
      refincometype: whtType?.id ?? null,
    },
  ];

  for (const t of templates) {
    const exists = await knex('budgetsource')
      .where({ code: t.code, fiscal_year: fy })
      .first('id');
    if (exists) continue;

    const row = {
      code: t.code,
      name: t.name,
      description: 'สร้างอัตโนมัติสำหรับทะเบียนเงินประกัน/ภาษีหัก ณ ที่จ่าย',
      fiscal_year: fy,
      budget_amount: 0,
      used_amount: 0,
      budget_type: 'นอกงปม',
      use: 'Y',
      refmoneygroup: t.refmoneygroup,
    };
    if (refBank) row.refbankaccount = refBank;
    if (t.refincometype) row.refincometype = t.refincometype;

    const hasRefBankCol = await knex.schema.hasColumn('budgetsource', 'refbankaccount');
    if (!hasRefBankCol) delete row.refbankaccount;
    const hasRefIncCol = await knex.schema.hasColumn('budgetsource', 'refincometype');
    if (!hasRefIncCol) delete row.refincometype;

    await knex('budgetsource').insert(row);
  }
};

exports.down = async function (knex) {
  const fy = String(currentFiscalYearBE());
  await knex('budgetsource')
    .whereIn('code', [`DEP-GUAR-${fy}`, `DEP-WHT-${fy}`])
    .del();
};
