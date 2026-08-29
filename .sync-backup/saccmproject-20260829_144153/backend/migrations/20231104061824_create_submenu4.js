/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("submenu4", function (table) {
        table.increments("id").primary();
        table.string("nameTH", 255).notNullable();
        table.string("nameEN", 255).notNullable();

        table.integer("refsubmenu3")
            .unsigned()
            .references("id")
            .inTable("submenu3")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");
        table.timestamp("created").defaultTo(knex.fn.now());
        table.timestamp("updated").defaultTo(knex.fn.now());

        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("submenu4");
};
