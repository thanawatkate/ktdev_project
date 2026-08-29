//ค่าเริ่มต้นที่จำเป็น
/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("docgroup", function (table) {
        table.increments("id").primary();
        table.string("tablename", 255).notNullable();
        table.string("name", 255).notNullable();
        // rungroup เช่น IV
        table.string("rungroup", 255).notNullable();
        table.string("docnoformat", 255).notNullable();
        table.string("runtaxgroup", 255).nullable();
        table.string("taxnoformat", 255).nullable();
        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("docgroup");
};
