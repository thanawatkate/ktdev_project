/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("bankaccount", function (table) {
        table.increments("id").primary();
        table.string("accountnumber").unique();
        table.string("accountname", 255).notNullable();
        table.integer("sort", 255).defaultTo(0);
        table.enu("use", ["Y", "N"], { useNative: true, existingType: true, enumName: "use" }).notNullable().defaultTo("Y");
        // บัญชีธนาคาร
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
    return knex.schema.dropTableIfExists("bankaccount");
};
