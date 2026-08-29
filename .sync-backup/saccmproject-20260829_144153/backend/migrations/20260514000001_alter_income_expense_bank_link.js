/**
 * ผูกรายรับ/รายจ่ายกับบัญชีเงินฝาก (bankaccount) — ใช้เป็น *override* ต่อเอกสาร
 * ค่าเริ่มต้นของบัญชีอยู่ที่ incometype.refbankaccount (ประเภทรายรับ)
 * + เพิ่ม expense.docdate ให้สอดคล้อง income (วันที่เอกสารจ่าย)
 */
exports.up = async function (knex) {
  const hasIncome = await knex.schema.hasTable('income');
  if (hasIncome) {
    const col = await knex.schema.hasColumn('income', 'refbankaccount');
    if (!col) {
      await knex.schema.alterTable('income', (t) => {
        t.integer('refbankaccount').unsigned().nullable()
          .references('id').inTable('bankaccount')
          .onUpdate('CASCADE').onDelete('SET NULL')
          .comment('บัญชีธนาคารที่รับเข้า (เมื่อชำระผ่านธนาคาร)');
      });
    }
  }

  const hasExpense = await knex.schema.hasTable('expense');
  if (hasExpense) {
    const hasDocdate = await knex.schema.hasColumn('expense', 'docdate');
    if (!hasDocdate) {
      await knex.schema.alterTable('expense', (t) => {
        t.timestamp('docdate').nullable().comment('วันที่เอกสารจ่าย (ว่าง = ใช้ created)');
      });
      await knex('expense').update({ docdate: knex.raw('created') });
    }

    const colBa = await knex.schema.hasColumn('expense', 'refbankaccount');
    if (!colBa) {
      await knex.schema.alterTable('expense', (t) => {
        t.integer('refbankaccount').unsigned().nullable()
          .references('id').inTable('bankaccount')
          .onUpdate('CASCADE').onDelete('SET NULL')
          .comment('บัญชีธนาคารที่จ่ายออก (เมื่อชำระผ่านธนาคาร/เช็ค)');
      });
    }
  }
};

exports.down = async function (knex) {
  const hasIncome = await knex.schema.hasTable('income');
  if (hasIncome && await knex.schema.hasColumn('income', 'refbankaccount')) {
    await knex.schema.alterTable('income', (t) => {
      t.dropForeign(['refbankaccount']);
      t.dropColumn('refbankaccount');
    });
  }
  const hasExpense = await knex.schema.hasTable('expense');
  if (hasExpense) {
    if (await knex.schema.hasColumn('expense', 'refbankaccount')) {
      await knex.schema.alterTable('expense', (t) => {
        t.dropForeign(['refbankaccount']);
        t.dropColumn('refbankaccount');
      });
    }
    if (await knex.schema.hasColumn('expense', 'docdate')) {
      await knex.schema.alterTable('expense', (t) => {
        t.dropColumn('docdate');
      });
    }
  }
};
