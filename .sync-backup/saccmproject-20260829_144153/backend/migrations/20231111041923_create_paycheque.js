/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("paycheque", function (table) {
        table.increments("id").primary();
        table.timestamp("created").defaultTo(knex.fn.now());
        table.timestamp("updated").defaultTo(knex.fn.now());
        table.double("chequeamount", 2).defaultTo(0.0);
        table.string("remark", 255).nullable();
        // ผู้รับเงิน
        table.integer("refchequeaccount")
            .unsigned()
            .references("id")
            .inTable("chequeaccount")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");

        // อ้างถึงตารางเงินออก
        table.integer("refexpense")
            .unsigned()
            .references("id")
            .inTable("expense")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");
    })
};
/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("paycheque");
};
