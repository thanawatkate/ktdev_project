/**
 * เติม refbankaccount ให้ประเภทรายรับที่ยังไม่มี (ใช้บัญชีแรกที่ use=Y) เพื่อรายงานเทียบยอด
 */
exports.up = async function (knex) {
  const hasIt = await knex.schema.hasTable('incometype');
  const hasBa = await knex.schema.hasTable('bankaccount');
  if (!hasIt || !hasBa) return;
  const first = await knex('bankaccount').where('use', 'Y').orderBy('id', 'asc').first('id');
  if (!first?.id) return;
  await knex('incometype')
    .where(function () {
      this.whereNull('refbankaccount').orWhere('refbankaccount', 0);
    })
    .update({ refbankaccount: first.id });
};

exports.down = async function () {
  // ไม่ rollback ค่า backfill — ข้อมูลอาจถูกแก้โดยผู้ใช้แล้ว
};
