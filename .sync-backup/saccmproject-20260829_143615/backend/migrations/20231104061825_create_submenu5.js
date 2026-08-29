/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("submenu5", function (table) {
        table.increments("id").primary();
        table.string("nameTH", 255).notNullable();
        table.string("nameEN", 255).notNullable();
        table.integer("refsubmenu4")
            .unsigned()
            .references("id")
            .inTable("submenu4")
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
    return knex.schema.dropTableIfExists("submenu5");
};
