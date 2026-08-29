/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("repayloansub", function (table) {
        table.increments("id").primary();
        table.timestamp("created").defaultTo(knex.fn.now());
        table.timestamp("updated").defaultTo(knex.fn.now());

        table.double("amount", 2).defaultTo(0.0).comment("ยอดเงินยืม");
        table.string("remark", 255).nullable();
        // ผู้รับเงิน
        table.integer("refrepayloan")
            .unsigned()
            .references("id")
            .inTable("repayloan")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");
        table.integer("refincometype")
            .unsigned()
            .references("id")
            .inTable("incometype")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");

    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("repayloansub");
};
