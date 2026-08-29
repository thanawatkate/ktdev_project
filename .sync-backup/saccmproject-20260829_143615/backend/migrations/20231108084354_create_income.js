/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
// รายรับ
exports.up = function (knex) {
    return knex.schema.createTable("income", function (table) {
        table.increments("id").primary();
        table.timestamp("created").defaultTo(knex.fn.now());
        table.timestamp("updated").defaultTo(knex.fn.now())
        table.timestamp("docdate").defaultTo(knex.fn.now())
        table.decimal("amount", 10).defaultTo(0.0);
        table.string("docno", 255).notNullable();
        table.string("detail", 255).nullable();
        table.string("remark", 255).nullable();
        // รับจาก
        table.integer("refuser")
            .unsigned()
            .references("id")
            .inTable("users")
            .onUpdate("CASCADE")
            .onDelete("SET NULL");

        // กลุ่มของเงินได้
        table.integer("refmoneytype")
            .unsigned()
            .references("id")
            .inTable("moneytype")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");

    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropTableIfExists("income");
};
