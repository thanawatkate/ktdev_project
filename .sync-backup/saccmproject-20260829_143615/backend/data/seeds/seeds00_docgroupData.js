/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> } 
 */


exports.seed = async function (knex) {

    const tableName = 'docgroup';
    return knex(tableName).del().then(_ => {
        return knex.raw(`ALTER TABLE ` + tableName + ` AUTO_INCREMENT = 1`).then(_ => {
            return knex(tableName).insert([
                { tablename: "income", name: "เลขที่เอกสารรับเงิน", rungroup: "INC", docnoformat: "{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}", runtaxgroup: null, taxnoformat: null, use: "Y" },
                { tablename: "loan", name: "เลขที่เอกสารยืมเงิน", rungroup: "LOAN", docnoformat: "{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}", runtaxgroup: null, taxnoformat: null, use: "Y" },
                { tablename: "expense_req", name: "เลขที่ใบขอเบิก", rungroup: "REQ", docnoformat: "{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}", runtaxgroup: null, taxnoformat: null, use: "Y" },
                { tablename: "repay_loan", name: "เลขที่เอกสารคืนเงินยืม", rungroup: "REPAY", docnoformat: "{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}", runtaxgroup: null, taxnoformat: null, use: "Y" },
            ]);
        })
    })

};
