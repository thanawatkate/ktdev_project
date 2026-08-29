/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
// ประเภทแหล่งที่มาของเงิน  เช่น เงินสด,เงินฝากธนาคาร,เงินฝากส่วนราชการผู้เบิก
exports.up = function (knex) {
    return knex.schema.createTable("moneygroup", function (table) {
        table.increments("id").primary();
        table.string("name", 255).notNullable();
        table.string("remark", 255).notNullable();
        table.integer("sort", 255).defaultTo(0);
        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("moneygroup");
};
