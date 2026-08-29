/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 *
 * ประเภทเงิน (moneygroup) — ตามระเบียบการคลังของส่วนราชการ
 * ใช้จำแนก fund_source (แหล่งเงิน) สำหรับทะเบียนคุมและรายงานทางการเงิน
 *
 * id (auto_increment) ที่จะได้หลัง seed (ลำดับตาม insert):
 *   1 = เงินรายได้แผ่นดิน
 *   2 = เงินนอกงบประมาณ
 *   3 = เงินภาษีหัก ณ ที่จ่าย
 *   4 = เงินประกันสัญญา
 *   5 = เงินงบประมาณ        ← เพิ่มใหม่ (ต่อท้ายเพื่อไม่กระทบ id เดิมบน DB ที่ seed ไปแล้ว)
 *
 * ลำดับการแสดงผลใน UI ใช้คอลัมน์ `sort` ไม่อ้าง id โดยตรง
 */
exports.seed = async function (knex) {
    const tableName = 'moneygroup';
    return knex(tableName).del().then(_ => {
        return knex.raw(`ALTER TABLE ` + tableName + ` AUTO_INCREMENT = 1`).then(_ => {
            return knex(tableName).insert([
                { name: "เงินรายได้แผ่นดิน",      remark: "", sort: 1 },
                { name: "เงินนอกงบประมาณ",        remark: "", sort: 3 },
                { name: "เงินภาษีหัก ณ ที่จ่าย",  remark: "", sort: 4 },
                { name: "เงินประกันสัญญา",        remark: "", sort: 5 },
                { name: "เงินงบประมาณ",           remark: "", sort: 2 },
            ]);
        });
    });
};
