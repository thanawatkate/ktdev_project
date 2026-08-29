/**
 * เพิ่มฟิลด์วงเงินเก็บรักษา (cash keeping limit) ตามขนาดโรงเรียน
 * อิงจากคู่มือหน้า 9: โรงเรียนเล็ก ≤120 คน 20K/30K, ใหญ่ >120 คน 30K/1M เป็นต้น
 *
 * โครงสร้างตาราง school_profile หาในระบบไม่พบในฝั่ง server (เก็บฝั่ง local เป็นหลัก)
 * จึงสร้างเป็นตารางใหม่ `cash_keeping_limit` แทน — มีหลายแถวต่อปีงบประมาณ + ประเภทเงิน
 */
exports.up = async function (knex) {
  await knex.schema.createTable('cash_keeping_limit', function (t) {
    t.increments('id').primary();
    t.string('fiscal_year', 4).notNullable();
    t.enu(
      'fund_kind',
      ['general', 'lunch', 'kosor', 'school_revenue', 'guarantee', 'other'],
      { useNative: true, existingType: false, enumName: 'cash_keeping_fund_enum' }
    ).notNullable().defaultTo('general')
      .comment('general=ทั่วไป, lunch=อาหารกลางวัน, kosor=กสศ., school_revenue=รายได้สถานศึกษา, guarantee=เงินประกันสัญญา');

    // เกณฑ์ตามขนาดโรงเรียน
    t.enu('school_size', ['small', 'big'], {
      useNative: true,
      existingType: false,
      enumName: 'cash_keeping_size_enum',
    }).notNullable().defaultTo('small')
      .comment('small=≤120 คน, big=>120 คน');

    t.decimal('cash_max', 15, 2).notNullable().defaultTo(0)
      .comment('วงเงินเก็บที่หน่วยงาน (เงินสด)');
    t.decimal('bank_max', 15, 2).notNullable().defaultTo(0)
      .comment('วงเงินฝากธนาคาร');
    t.text('remark').nullable();
    t.enu('use', ['Y', 'N'], { useNative: true, existingType: true, enumName: 'use' })
      .notNullable().defaultTo('Y');

    t.timestamp('created').defaultTo(knex.fn.now());
    t.timestamp('updated').defaultTo(knex.fn.now());
    t.unique(['fiscal_year', 'fund_kind', 'school_size']);
  });

  // seed ค่าเริ่มต้นตามคู่มือ
  const currentYear = (new Date().getFullYear() + 543).toString();
  const seeds = [
    { fund_kind: 'general',        school_size: 'small', cash_max: 20000, bank_max: 30000,    remark: 'โรงเรียน ≤120 คน — คู่มือ พ.ศ.2544' },
    { fund_kind: 'general',        school_size: 'big',   cash_max: 30000, bank_max: 1000000,  remark: 'โรงเรียน >120 คน — คู่มือ พ.ศ.2544' },
    { fund_kind: 'lunch',          school_size: 'small', cash_max: 50000, bank_max: 200000,   remark: 'เงินอุดหนุนโครงการอาหารกลางวัน' },
    { fund_kind: 'lunch',          school_size: 'big',   cash_max: 50000, bank_max: 200000,   remark: 'เงินอุดหนุนโครงการอาหารกลางวัน' },
    { fund_kind: 'kosor',          school_size: 'small', cash_max: 20000, bank_max: 30000,    remark: 'เงิน กสศ.' },
    { fund_kind: 'kosor',          school_size: 'big',   cash_max: 20000, bank_max: 30000,    remark: 'เงิน กสศ.' },
    { fund_kind: 'school_revenue', school_size: 'small', cash_max: 20000, bank_max: 30000,    remark: 'เงินรายได้สถานศึกษา' },
    { fund_kind: 'school_revenue', school_size: 'big',   cash_max: 30000, bank_max: 1000000,  remark: 'เงินรายได้สถานศึกษา' },
  ];
  for (const s of seeds) {
    await knex('cash_keeping_limit').insert({ ...s, fiscal_year: currentYear }).onConflict(['fiscal_year', 'fund_kind', 'school_size']).ignore();
  }
};

exports.down = function (knex) {
  return knex.schema.dropTableIfExists('cash_keeping_limit');
};
