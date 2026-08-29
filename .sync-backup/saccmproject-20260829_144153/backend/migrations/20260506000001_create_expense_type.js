/**
 * สร้างตาราง expensetype สำหรับจำแนกประเภทรายจ่าย
 * ตามระเบียบกระทรวงการคลังว่าด้วยการจัดซื้อจัดจ้างฯ พ.ศ. 2560
 * และแนวปฏิบัติของสถานศึกษาในสังกัด สพฐ.
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
    await knex.schema.createTable('expensetype', function (table) {
        table.increments('id').primary();
        table.string('code', 10).notNullable().comment('รหัสประเภท เช่น 01, 02');
        table.string('name', 255).notNullable().comment('ชื่อประเภทรายจ่าย');
        table.string('remark', 500).nullable().comment('คำอธิบายเพิ่มเติม');
        table.integer('sort').defaultTo(0).comment('ลำดับการแสดงผล');
        table.enu('use', ['Y', 'N'], {
            useNative: true,
            existingType: true,
            enumName: 'use',
        }).notNullable().defaultTo('Y');
    });

    // ค่าเริ่มต้น 8 ประเภทตามระเบียบพัสดุ
    await knex('expensetype').insert([
        {
            code: '01',
            name: 'ค่าตอบแทน',
            remark: 'ค่าจ้าง ค่าตอบแทนบุคลากร โบนัส ค่าตอบแทนพิเศษ',
            sort: 1,
            use: 'Y',
        },
        {
            code: '02',
            name: 'ค่าใช้สอย',
            remark: 'ค่าเช่า ค่าเดินทาง ค่าจัดงาน ค่าพิมพ์ ค่าบริการ',
            sort: 2,
            use: 'Y',
        },
        {
            code: '03',
            name: 'ค่าวัสดุ',
            remark: 'วัสดุสำนักงาน วัสดุการศึกษา วัสดุงานบ้าน อุปกรณ์กีฬา',
            sort: 3,
            use: 'Y',
        },
        {
            code: '04',
            name: 'ค่าสาธารณูปโภค',
            remark: 'ค่าน้ำประปา ค่าไฟฟ้า ค่าโทรศัพท์ ค่าอินเทอร์เน็ต',
            sort: 4,
            use: 'Y',
        },
        {
            code: '05',
            name: 'ค่าครุภัณฑ์',
            remark: 'คอมพิวเตอร์ เครื่องพิมพ์ เฟอร์นิเจอร์ อุปกรณ์ครุภัณฑ์',
            sort: 5,
            use: 'Y',
        },
        {
            code: '06',
            name: 'ค่าที่ดินและสิ่งก่อสร้าง',
            remark: 'ที่ดิน อาคารเรียน ห้องเรียน ซ่อมแซมอาคาร',
            sort: 6,
            use: 'Y',
        },
        {
            code: '07',
            name: 'เงินอุดหนุน',
            remark: 'เงินสนับสนุนนักเรียน ทุนการศึกษา เงินช่วยเหลือ',
            sort: 7,
            use: 'Y',
        },
        {
            code: '08',
            name: 'รายจ่ายอื่น',
            remark: 'รายจ่ายที่ไม่จัดอยู่ในประเภทข้างต้น',
            sort: 8,
            use: 'Y',
        },
    ]);
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
    await knex.schema.dropTableIfExists('expensetype');
};
