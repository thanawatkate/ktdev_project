exports.up = async function (knex) {
  const exists = await knex('docgroup')
    .where('tablename', 'receipt_book')
    .first();

  if (exists) return;

  await knex('docgroup').insert({
    tablename: 'receipt_book',
    name: 'รูปแบบเล่มใบเสร็จ',
    rungroup: 'RB',
    docnoformat: '{RUN3}',
    use: 'Y',
  });
};

exports.down = async function (knex) {
  await knex('docgroup').where('tablename', 'receipt_book').del();
};
