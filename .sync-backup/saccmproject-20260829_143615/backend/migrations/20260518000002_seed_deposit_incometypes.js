/**
 * หมวดรายรับสำหรับทะเบียนเงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย
 * (ใช้กับ receive-with-income — ต้องมี refincometype + บัญชีธนาคาร)
 */
exports.up = async function (knex) {
  const hasTable = await knex.schema.hasTable('incometype');
  if (!hasTable) return;

  let refBank = null;
  const ba = await knex('bankaccount').select('id').orderBy('id', 'asc').first();
  if (ba?.id) refBank = ba.id;
  if (!refBank) {
    const it = await knex('incometype')
      .whereNotNull('refbankaccount')
      .select('refbankaccount')
      .first();
    refBank = it?.refbankaccount ?? null;
  }

  const rows = [
    { code: 'GUAR-01', name: 'เงินประกันสัญญา', sort: 201 },
    { code: 'WHT-01', name: 'ภาษีหัก ณ ที่จ่าย (ทะเบียนคุม)', sort: 202 },
  ];

  for (const row of rows) {
    const exists = await knex('incometype').where('code', row.code).first('id');
    if (exists) continue;
    await knex('incometype').insert({
      code: row.code,
      name: row.name,
      sort: row.sort,
      use: 'Y',
      refbankaccount: refBank,
    });
  }
};

exports.down = async function (knex) {
  await knex('incometype').whereIn('code', ['GUAR-01', 'WHT-01']).del();
};
