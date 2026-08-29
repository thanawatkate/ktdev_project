/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("chequeaccount", function (table) {
        table.increments("id").primary();
        table.string("chequeno").unique();
        table.string("chequemame", 255).notNullable();
        table.integer("sort", 255).defaultTo(0);
        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
        // ธนาคาร
        table.integer("refbank")
            .unsigned()
            .notNullable()
            .references("id")
            .inTable("bank")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("chequeaccount");
};
