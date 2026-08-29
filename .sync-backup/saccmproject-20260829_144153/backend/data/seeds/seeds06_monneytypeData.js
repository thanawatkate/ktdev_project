/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> } 
 */


exports.seed = async function (knex) {

    const tableName = 'moneytype';
    return knex(tableName).del().then(_ => {
        return knex.raw(`ALTER TABLE ` + tableName + ` AUTO_INCREMENT = 1`).then(_ => {
            return knex(tableName).insert([
                { name: "เงินสด", remark: "", sort: 1, use: "Y" },
                { name: "เงินโอน", remark: "", sort: 2, use: "Y" },
                { name: "เช็ค", remark: "", sort: 3, use: "Y" },
                { name: "เงินฝากส่วนราชการผู้เบิก", remark: "", sort: 4, use: "Y" }
            ]);
        })
    })

};
