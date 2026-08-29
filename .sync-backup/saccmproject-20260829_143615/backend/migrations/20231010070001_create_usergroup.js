//ค่าเริ่มต้นที่จำเป็น
/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("usergroup", function (table) {
        table.increments("id").primary();
        table.string("nameth", 255).notNullable();
        table.string("nameen", 255).notNullable();
        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("usergroup");
};
