/**
 * แก้ไข expensesub:
 *   - เพิ่ม refexpensetype  FK → expensetype
 *   - ลบ refincometype ออก (ใช้ผิด concept — รายจ่ายไม่ควรอ้างตาราง incometype)
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
    // เพิ่ม FK ใหม่
    await knex.schema.table('expensesub', function (table) {
        table.integer('refexpensetype')
            .unsigned()
            .nullable()
            .references('id')
            .inTable('expensetype')
            .onUpdate('CASCADE')
            .onDelete('SET NULL')
            .comment('ประเภทรายจ่ายตามระเบียบพัสดุ');
    });

    // ลบ FK refincometype ที่ใช้ผิด concept ออก
    await knex.schema.table('expensesub', function (table) {
        table.dropForeign(['refincometype']);
        table.dropColumn('refincometype');
    });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
    // คืน refincometype
    await knex.schema.table('expensesub', function (table) {
        table.integer('refincometype')
            .unsigned()
            .nullable()
            .references('id')
            .inTable('incometype')
            .onUpdate('CASCADE')
            .onDelete('CASCADE');
    });

    // ลบ refexpensetype
    await knex.schema.table('expensesub', function (table) {
        table.dropForeign(['refexpensetype']);
        table.dropColumn('refexpensetype');
    });
};
