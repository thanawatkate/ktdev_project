/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
// ประเภทของเงิน เช่น ค่าอุปกรณ์การเรียน,เงินอุดหนุดรายหัว
exports.up = function (knex) {
    return knex.schema.createTable("incometype", function (table) {
        table.increments("id").primary();
        table.string("name", 255).notNullable();
        table.string("remark", 255).nullable();
        table.integer("sort", 255).defaultTo(0);

        // บัญชีธนาคาร
        table.integer("refmoneygroup")
            .unsigned()
            .references("id")
            .inTable("moneygroup")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");

        // บัญชีธนาคาร
        table.integer("refbankaccount")
            .unsigned()
            .references("id")
            .inTable("bankaccount")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");

        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("incometype");
};
