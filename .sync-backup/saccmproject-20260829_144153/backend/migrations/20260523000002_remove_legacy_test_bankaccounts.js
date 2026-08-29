const FRONTEND_BANK_CODES = [
  '002', '006', '025', '004', '014', '011', '022', '024', '073',
  '070', '069', '067', '034', '030', '033', '066', '065',
];

exports.up = async function (knex) {
  const hasBankAccount = await knex.schema.hasTable('bankaccount');
  if (!hasBankAccount) return;

  const legacyRows = await knex('bankaccount')
    .select('id')
    .whereIn('accountnumber', ['test1', 'test2', 'test3']);
  const legacyIds = legacyRows.map((row) => row.id);

  if (legacyIds.length > 0) {
    const nullableRefs = [
      ['incometype', 'refbankaccount'],
      ['budgetsource', 'refbankaccount'],
      ['income', 'refbankaccount'],
      ['expense', 'refbankaccount'],
      ['deposit_guarantee', 'refbankaccount'],
    ];
    for (const [tableName, columnName] of nullableRefs) {
      if (
        (await knex.schema.hasTable(tableName)) &&
        (await knex.schema.hasColumn(tableName, columnName))
      ) {
        await knex(tableName).whereIn(columnName, legacyIds).update({
          [columnName]: null,
        });
      }
    }

    await knex('bankaccount').whereIn('id', legacyIds).del();
  }

  if (await knex.schema.hasTable('bank')) {
    await knex('bank')
      .whereNotIn('code', FRONTEND_BANK_CODES)
      .whereNotExists(function () {
        this.select(1).from('bankaccount').whereRaw('bankaccount.refbank = bank.id');
      })
      .del();
  }
};

exports.down = async function () {
  // Do not recreate legacy test accounts.
};
