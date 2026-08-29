/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("expensereq", function (table) {
        table.increments("id").primary();
        table.timestamp("created").defaultTo(knex.fn.now());
        table.timestamp("updated").defaultTo(knex.fn.now());
        table.string("docno", 255).notNullable();
        table.double("amount", 2).defaultTo(0.0);
        table.string("remark", 255).nullable();

        // ผู้รับเงิน
        table.integer("refmember")
            .unsigned()
            .references("id")
            .inTable("member")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("expensereq");
};
