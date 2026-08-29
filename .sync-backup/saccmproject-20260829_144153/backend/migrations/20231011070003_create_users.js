//ค่าเริ่มต้นที่จำเป็น
/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    return knex.schema.createTable("users", function (table) {
        table.increments("id").primary();
        table.string("code").unique();
        table.string("email").notNullable().unique();
        table.string("username").notNullable();
        table.string("password").notNullable();
        table.string("name").notNullable();
        table.string("lastname").notNullable();
        table.string("contactnumber").notNullable();

        table.integer("refusergroup")
            .unsigned()
            .references("id")
            .inTable("usergroup")
            .onUpdate("CASCADE")
            .onDelete("CASCADE");

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
    return knex.schema.dropTableIfExists("users");
};
