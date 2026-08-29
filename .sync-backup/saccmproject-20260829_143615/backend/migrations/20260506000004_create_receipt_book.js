/**
 * ทะเบียนคุมใบเสร็จรับเงิน (Receipt Book Register) — ตามคู่มือหน้า 35
 *
 *   - receipt_book: 1 แถว = 1 เล่ม (มีเล่มที่, เลขที่เริ่ม-สิ้นสุด, สถานะ)
 *   - receipt_issue: log การจ่าย/รับ/ยกเลิกใบเสร็จ ในเล่มนั้น ๆ
 */
exports.up = async function (knex) {
  await knex.schema.createTable('receipt_book', function (t) {
    t.increments('id').primary();
    t.string('book_no', 32).notNullable().comment('เล่มที่');
    t.string('receipt_type', 64).notNullable().defaultTo('บร.')
      .comment('ประเภท เช่น บร., บค., บฝ.');
    t.string('start_no', 32).notNullable().comment('เลขที่เริ่ม');
    t.string('end_no', 32).notNullable().comment('เลขที่สุดท้าย');
    t.string('fiscal_year', 4).notNullable();
    t.enu('status', ['available', 'in_use', 'closed', 'cancelled'], {
      useNative: true,
      existingType: false,
      enumName: 'receipt_book_status_enum',
    }).notNullable().defaultTo('available');
    t.timestamp('received_at').defaultTo(knex.fn.now()).comment('วันที่รับเล่ม');
    t.string('received_from', 255).nullable().comment('รับมาจาก');
    t.text('remark').nullable();
    t.timestamp('created').defaultTo(knex.fn.now());
    t.timestamp('updated').defaultTo(knex.fn.now());
    t.unique(['book_no', 'fiscal_year', 'receipt_type']);
  });

  await knex.schema.createTable('receipt_issue', function (t) {
    t.increments('id').primary();
    t.integer('refbook').unsigned().notNullable()
      .references('id').inTable('receipt_book')
      .onUpdate('CASCADE').onDelete('CASCADE');
    t.string('receipt_no', 32).notNullable().comment('เลขที่ใบเสร็จที่ใช้');
    t.timestamp('issued_at').defaultTo(knex.fn.now()).comment('วันที่ใช้');
    t.string('issued_to', 255).nullable().comment('ออกให้ใคร');
    t.decimal('amount', 15, 2).defaultTo(0);
    t.enu('issue_status', ['used', 'cancelled', 'spoiled'], {
      useNative: true,
      existingType: false,
      enumName: 'receipt_issue_status_enum',
    }).notNullable().defaultTo('used');
    t.text('remark').nullable();

    // optional: link กลับไปยัง income/expense
    t.integer('refincome').unsigned().nullable()
      .references('id').inTable('income')
      .onUpdate('CASCADE').onDelete('SET NULL');

    t.timestamp('created').defaultTo(knex.fn.now());
    t.unique(['refbook', 'receipt_no']);
  });
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('receipt_issue');
  await knex.schema.dropTableIfExists('receipt_book');
};
