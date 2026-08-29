/**
 * จัดการให้ DB ที่ seed ไปแล้วสอดคล้องกับคู่มือการปฏิบัติงานการเงิน พ.ศ. 2544
 * (ดู `.cursor/rules/10-saccm-domain-core.mdc`)
 *
 * 1) เพิ่ม expense_type "00 งบบุคลากร — ค่าจ้างชั่วคราว"
 *    เพื่อให้รายงานรับ-จ่ายประจำปี (คู่มือหน้า 33) มีหมวด "งบบุคลากร" ครบ
 *
 * 2) อัปเดต incometype OB-07 จาก "เงินบำรุงลูกเสือ-เนตรนารี"
 *    → "เงินบำรุงลูกเสือ-เนตรนารี-ยุวกาชาด"
 *    เพื่อรวม section 2.2.4-2.2.6 (หน้า 10) ตามคู่มือ
 *
 * 3) อัปเดต remark ของ cash_keeping_limit ให้สื่อความชัดเจน
 *    (general = alias ของ school_revenue, kosor = เกณฑ์ภายใน)
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  // (1) expense_type 00 — งบบุคลากร / ค่าจ้างชั่วคราว
  if (await knex.schema.hasTable('expensetype')) {
    const existing = await knex('expensetype').where('code', '00').first();
    if (!existing) {
      await knex('expensetype').insert({
        code: '00',
        name: 'งบบุคลากร — ค่าจ้างชั่วคราว',
        remark: 'ค่าจ้างลูกจ้างชั่วคราวจากเงินรายได้สถานศึกษา (รายการที่ 1 ในรายงานหน้า 33)',
        sort: 0,
        use: 'Y',
      });
    }
  }

  // (2) incometype OB-07 — เพิ่มยุวกาชาด
  if (await knex.schema.hasTable('incometype')) {
    await knex('incometype')
      .where('code', 'OB-07')
      .update({
        name: 'เงินบำรุงลูกเสือ-เนตรนารี-ยุวกาชาด',
        remark: 'เงินนอกงบประมาณ — รวมลูกเสือ/เนตรนารี/ยุวกาชาด ตามคู่มือ พ.ศ. 2544 หน้า 10 (sections 2.2.4-2.2.6)',
      });
  }

  // (3) cash_keeping_limit remark
  if (await knex.schema.hasTable('cash_keeping_limit')) {
    const updates = [
      { fund_kind: 'general',        school_size: 'small', remark: 'alias ของ school_revenue (เก็บไว้เพื่อ backward-compat)' },
      { fund_kind: 'general',        school_size: 'big',   remark: 'alias ของ school_revenue (เก็บไว้เพื่อ backward-compat)' },
      { fund_kind: 'lunch',          school_size: 'small', remark: 'เงินอุดหนุนโครงการอาหารกลางวัน — คู่มือหน้า 9 ตาราง 2' },
      { fund_kind: 'lunch',          school_size: 'big',   remark: 'เงินอุดหนุนโครงการอาหารกลางวัน — คู่มือหน้า 9 ตาราง 2' },
      { fund_kind: 'kosor',          school_size: 'small', remark: 'เงิน กสศ. — เกณฑ์ภายใน (คู่มือไม่ระบุชัดเจน)' },
      { fund_kind: 'kosor',          school_size: 'big',   remark: 'เงิน กสศ. — เกณฑ์ภายใน (คู่มือไม่ระบุชัดเจน)' },
      { fund_kind: 'school_revenue', school_size: 'small', remark: 'เงินรายได้สถานศึกษา ≤120 คน — คู่มือหน้า 9 ตาราง 1 (+เงินสดสำรองอาหารกลางวัน 20K/วัน)' },
      { fund_kind: 'school_revenue', school_size: 'big',   remark: 'เงินรายได้สถานศึกษา >120 คน — คู่มือหน้า 9 ตาราง 1 (+เงินสดสำรองอาหารกลางวัน 20K/วัน)' },
    ];
    for (const u of updates) {
      await knex('cash_keeping_limit')
        .where({ fund_kind: u.fund_kind, school_size: u.school_size })
        .update({ remark: u.remark });
    }
  }
};

exports.down = async function (knex) {
  if (await knex.schema.hasTable('expensetype')) {
    await knex('expensetype').where('code', '00').del();
  }
  if (await knex.schema.hasTable('incometype')) {
    await knex('incometype')
      .where('code', 'OB-07')
      .update({ name: 'เงินบำรุงลูกเสือ-เนตรนารี' });
  }
};
