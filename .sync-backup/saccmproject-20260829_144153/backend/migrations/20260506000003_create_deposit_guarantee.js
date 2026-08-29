/**
 * เงินประกันสัญญา / เงินภาษีหัก ณ ที่จ่าย — ตามคู่มือ "เงินนอกงบประมาณที่ต้องคืนผู้มีสิทธิ์"
 *
 * วงจร: รับเข้า → ฝากธนาคาร/เก็บที่หน่วยงาน → คืน/นำส่งสรรพากร เมื่อถึงกำหนด
 *
 * ใช้ table แยกจาก income/expense เพราะ flow ต่างกัน (ไม่ใช่งบประมาณรายจ่าย)
 */
exports.up = async function (knex) {
  await knex.schema.createTable('deposit_guarantee', function (t) {
    t.increments('id').primary();
    t.string('docno', 64).notNullable().comment('เลขที่เอกสาร');
    t.timestamp('docdate').defaultTo(knex.fn.now()).comment('วันที่รับเงิน');
    t.enu(
      'deposit_type',
      ['contract_guarantee', 'withholding_tax', 'other'],
      { useNative: true, existingType: false, enumName: 'deposit_guarantee_type_enum' }
    ).notNullable().comment('ประเภทเงิน');
    t.decimal('amount', 15, 2).notNullable().defaultTo(0);

    // ข้อมูลคู่สัญญา/ผู้ที่ต้องคืนเงินให้
    t.integer('refparty').unsigned().nullable()
      .references('id').inTable('party')
      .onUpdate('CASCADE').onDelete('SET NULL')
      .comment('คู่สัญญา/ผู้รับเงินคืน');
    t.string('party_name_snapshot', 255).nullable();

    t.string('contract_no', 100).nullable().comment('เลขที่สัญญา');
    t.text('detail').nullable();
    t.timestamp('due_date').nullable().comment('วันครบกำหนดคืน/นำส่ง');

    // ที่เก็บเงิน
    t.integer('refbankaccount').unsigned().nullable()
      .references('id').inTable('bankaccount')
      .onUpdate('CASCADE').onDelete('SET NULL')
      .comment('ฝากธนาคารบัญชีใด (ถ้ามี)');

    // สถานะการคืน
    t.enu('status', ['holding', 'returned', 'submitted', 'forfeited'], {
      useNative: true,
      existingType: false,
      enumName: 'deposit_guarantee_status_enum',
    }).notNullable().defaultTo('holding')
      .comment('holding=ถือไว้, returned=คืนแล้ว, submitted=นำส่งคลัง/สรรพากร, forfeited=ริบ');
    t.timestamp('settled_at').nullable().comment('วันที่ดำเนินการคืน/นำส่ง');
    t.string('settled_docno', 64).nullable().comment('เลขที่เอกสารคืน/นำส่ง');
    t.text('settled_remark').nullable();

    t.timestamp('created').defaultTo(knex.fn.now());
    t.timestamp('updated').defaultTo(knex.fn.now());
    t.string('fiscal_year', 4).nullable();
  });
};

exports.down = function (knex) {
  return knex.schema.dropTableIfExists('deposit_guarantee');
};
