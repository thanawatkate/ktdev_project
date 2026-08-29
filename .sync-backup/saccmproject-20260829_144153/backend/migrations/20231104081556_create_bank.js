/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("bank", function (table) {
        table.increments("id").primary();
        table.string("name", 255).notNullable();
        table.string("shortname", 255).notNullable();
        table.string("code", 5).notNullable();
        table.integer("sort", 255).defaultTo(0);
        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("bank");
};
