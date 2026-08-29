/**
 * fiscal_year_opening — ยอดยกมาต้นปีงบประมาณ จำแนกตาม bucket × pocket
 *
 * อ้างอิงคู่มือการเงินหน้า 34 (รายงานเงินคงเหลือประจำวัน) ที่ต้องแสดง 7 แถว
 * × 3 pocket (เงินสด / เงินฝากธนาคาร / ส่วนราชการผู้เบิก)
 *
 * bucket: 'budget' | 'state_revenue' | 'offbudget' | 'general_subsidy'
 *       | 'school_revenue' | 'withholding_tax' | 'contract_deposit'
 * pocket: 'cash' | 'bank' | 'agency'
 *
 * - UNIQUE(fiscal_year, bucket, pocket) — แต่ละ slot มีค่าเดียวต่อปี
 * - ใช้สำหรับเสริม "ยอดยกมา" ในรายงานหน้า 34 + 33 + ทะเบียนคุมต่าง ๆ
 *   เมื่อระบบยังไม่มีข้อมูล transaction ของปีก่อนครบถ้วน
 */
exports.up = async function (knex) {
  const has = await knex.schema.hasTable('fiscal_year_opening');
  if (!has) {
    await knex.schema.createTable('fiscal_year_opening', function (t) {
      t.increments('id').primary();
      t.string('fiscal_year', 4).notNullable().comment('ปีงบประมาณ พ.ศ.');
      t.string('bucket', 32).notNullable()
        .comment('budget|state_revenue|offbudget|general_subsidy|school_revenue|withholding_tax|contract_deposit');
      t.string('pocket', 16).notNullable().comment('cash|bank|agency');
      t.decimal('opening_amount', 15, 2).notNullable().defaultTo(0)
        .comment('ยอดยกมาต้นปี (บาท)');
      t.string('remark', 255).nullable();
      t.string('use', 1).notNullable().defaultTo('Y');
      t.string('source', 16).notNullable().defaultTo('manual')
        .comment('manual|computed|year_end_close');
      t.timestamp('created').defaultTo(knex.fn.now());
      t.timestamp('updated').defaultTo(knex.fn.now());
      t.unique(['fiscal_year', 'bucket', 'pocket'], { indexName: 'uq_fy_opening_slot' });
      t.index(['fiscal_year'], 'idx_fy_opening_year');
    });
  }
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('fiscal_year_opening');
};
