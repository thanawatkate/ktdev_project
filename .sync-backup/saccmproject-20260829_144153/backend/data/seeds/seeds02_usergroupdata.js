/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> } 
 */

exports.seed = async function (knex) {
    // Deletes ALL existing entries
    const tableName = 'usergroup';
    return knex(tableName).del().then(_ => {
        return knex.raw(`ALTER TABLE ` + tableName + ` AUTO_INCREMENT = 1`).then(_ => {
            return knex(tableName).insert([
                { nameth: "ผู้ดูแลระบบ", nameen: "admin", use: "Y" },
                { nameth: "เจ้าหน้าที่", nameen: "officer", use: "Y" },
            ]);
        })
    })
};
