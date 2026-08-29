/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> } 
 */


exports.seed = async function (knex) {

    const tableName = 'bank';
    return knex(tableName).del().then(_ => {
        return knex.raw(`ALTER TABLE ` + tableName + ` AUTO_INCREMENT = 1`).then(_ => {
            return knex(tableName).insert([
                { name: "ธนาคารกรุงเทพ", shortname: "BBL", code: "002", sort: 1, use: "Y" },
                { name: "ธนาคารกรุงไทย", shortname: "KTB", code: "006", sort: 2, use: "Y" },
                { name: "ธนาคารกรุงศรีอยุธยา", shortname: "BAY", code: "025", sort: 3, use: "Y" },
                { name: "ธนาคารกสิกรไทย", shortname: "KBANK", code: "004", sort: 4, use: "Y" },
                { name: "ธนาคารไทยพาณิชย์", shortname: "SCB", code: "014", sort: 5, use: "Y" },
                { name: "ธนาคารทหารไทยธนชาต", shortname: "TTB", code: "011", sort: 6, use: "Y" },
                { name: "ธนาคารซีไอเอ็มบี ไทย", shortname: "CIMBT", code: "022", sort: 7, use: "Y" },
                { name: "ธนาคารยูโอบี", shortname: "UOB", code: "024", sort: 8, use: "Y" },
                { name: "ธนาคารแลนด์ แอนด์ เฮ้าส์", shortname: "LHBANK", code: "073", sort: 9, use: "Y" },
                { name: "ธนาคารไอซีบีซี (ไทย)", shortname: "ICBC", code: "070", sort: 10, use: "Y" },
                { name: "ธนาคารเกียรตินาคินภัทร", shortname: "KKP", code: "069", sort: 11, use: "Y" },
                { name: "ธนาคารทิสโก้", shortname: "TISCO", code: "067", sort: 12, use: "Y" },
                { name: "ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร", shortname: "BAAC", code: "034", sort: 13, use: "Y" },
                { name: "ธนาคารออมสิน", shortname: "GSB", code: "030", sort: 14, use: "Y" },
                { name: "ธนาคารอาคารสงเคราะห์", shortname: "GHB", code: "033", sort: 15, use: "Y" },
                { name: "ธนาคารอิสลามแห่งประเทศไทย", shortname: "iBank", code: "066", sort: 16, use: "Y" },
                { name: "ธนาคารเพื่อการส่งออกและนำเข้าแห่งประเทศไทย", shortname: "EXIM", code: "065", sort: 17, use: "Y" }
            ]);
        })
    })

};
