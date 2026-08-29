/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> } 
 */


exports.seed = async function (knex) {
    // Frontend SQLite ไม่มีบัญชีธนาคารเริ่มต้น; ผู้ใช้ต้องเพิ่มบัญชีจริงเอง
    // จึงไม่ seed บัญชี test ใน backend แล้ว เพื่อให้ master data เริ่มต้นตรงกัน
    return Promise.resolve();
};
