/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
//ประเภทการจ่าย เช่น ใบสำคัญคู่จ่าย,ใบสำคัญรับเงิน,เงินยืม,อื่นๆ

exports.up = function (knex) {
    return knex.schema.createTable("paymentmethods", function (table) {
        table.increments("id").primary();
        table.string("name", 255).notNullable();
        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
        table.timestamp("created").defaultTo(knex.fn.now());
        table.timestamp("updated").defaultTo(knex.fn.now());
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("paymentmethods");

};
