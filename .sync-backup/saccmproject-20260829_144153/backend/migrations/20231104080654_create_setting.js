/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("setting", function (table) {
        table.increments("id").primary();
        table.string("nameTH", 255).notNullable();
        table.string("nameEn", 255).notNullable();
        table.integer("sort", 255).defaultTo(0);
        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("setting");
};
