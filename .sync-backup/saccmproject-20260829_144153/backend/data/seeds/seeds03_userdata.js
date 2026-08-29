/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> } 
 */

const passwordManage = require('../../src/utils/haspassword/hashpassword.util');


exports.seed = async function (knex) {

    const tableName = 'users';
    const adminPassword = await passwordManage.hashPassword('adminadmin1234');
    const officerPassword = await passwordManage.hashPassword('officerofficer1234');
    // Deletes ALL existing entries 
    return knex(tableName).del().then(_ => {
        return knex.raw(`ALTER TABLE ` + tableName + ` AUTO_INCREMENT = 1`).then(_ => {

            return knex(tableName).insert([
                {
                    code: "01",
                    email: "admin@saccm.local",
                    username: "admin",
                    password: adminPassword,
                    name: "Admin",
                    lastname: "System",
                    contactnumber: "",
                    refusergroup: "1",
                    refprefix: null
                },
                {
                    code: "02",
                    email: "officer@saccm.local",
                    username: "officer",
                    password: officerPassword,
                    name: "Officer",
                    lastname: "User",
                    contactnumber: "",
                    refusergroup: "2",
                    refprefix: null
                },
            ]);

        })

    })

};
