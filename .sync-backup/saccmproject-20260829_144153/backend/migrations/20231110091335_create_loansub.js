/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {

    return knex.schema.createTable("loansub", function (table) {
        table.increments("id").primary();
        table.timestamp("created").defaultTo(knex.fn.now());
        table.timestamp("updated").defaultTo(knex.fn.now());

        table.integer("refloan")
            .unsigned()
            .references("id")
            .inTable("loan")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");

        table.integer("refincometype")
            .unsigned()
            .references("id")
            .inTable("incometype")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");

        table.double("amount", 2).defaultTo(0.0);
        table.string("remark", 255).nullable();

    })

};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("loansub");
};
