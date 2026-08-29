/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("member", function (table) {
        table.increments("id").primary();
        table.string("code").unique();
        table.string("email").notNullable();
        table.string("name").notNullable();
        table.string("lastname").notNullable();
        table.string("contactnumber").notNullable();
        table.string("address").nullable();


        table.integer("refprefix")
            .unsigned()
            .references("id")
            .inTable("prefix")
            .onUpdate("CASCADE")
            .onDelete("SET NULL");

        table.timestamp("created").defaultTo(knex.fn.now());
        table.timestamp("updated").defaultTo(knex.fn.now());
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("member");
};
