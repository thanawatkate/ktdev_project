/**
 * แหล่งเงิน / งบประมาณ
 * ตามระเบียบกระทรวงการคลัง แบ่งเป็น:
 *   - งบประมาณแผ่นดิน (งปม.)
 *   - เงินนอกงบประมาณ
 *   - เงินอุดหนุนทั่วไป
 *   - เงินอุดหนุนเฉพาะกิจ
 *   - เงินรายได้สถานศึกษา
 */
exports.up = function (knex) {
  return knex.schema.createTable('budgetsource', function (table) {
    table.increments('id').primary();
    table.string('code', 20).notNullable().comment('รหัสแหล่งเงิน เช่น 2101, 2102');
    table.string('name', 255).notNullable().comment('ชื่อแหล่งเงิน');
    table.text('description').nullable().comment('คำอธิบายเพิ่มเติม');
    table.string('fiscal_year', 4).notNullable().comment('ปีงบประมาณ เช่น 2568');
    table.decimal('budget_amount', 15, 2).defaultTo(0).comment('วงเงินที่ได้รับจัดสรร');
    table.decimal('used_amount', 15, 2).defaultTo(0).comment('ยอดที่ใช้จ่ายแล้ว (คำนวณจาก expense)');
    table.enu('budget_type', ['งปม', 'นอกงปม', 'อุดหนุนทั่วไป', 'อุดหนุนเฉพาะกิจ', 'รายได้สถานศึกษา'], {
      useNative: true,
      existingType: false,
      enumName: 'budget_type_enum',
    }).notNullable().defaultTo('งปม').comment('ประเภทงบประมาณ');
    table.enu('use', ['Y', 'N'], {
      useNative: true,
      existingType: true,
      enumName: 'use',
    }).notNullable().defaultTo('Y');
    table.timestamp('created').defaultTo(knex.fn.now());
    table.timestamp('updated').defaultTo(knex.fn.now());
  });
};

exports.down = function (knex) {
  return knex.schema.dropTableIfExists('budgetsource');
};
