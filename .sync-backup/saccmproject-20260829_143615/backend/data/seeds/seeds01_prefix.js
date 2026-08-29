/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> } 
 */



exports.seed = async function (knex) {

    // Deletes ALL existing entries
    const tableName = "prefix"
    return knex(tableName).del()
        .then(function () {
            // Inserts seed entries
            return knex.raw('ALTER TABLE ' + tableName + ' AUTO_INCREMENT = 1').then(_ => {
                return knex(tableName).insert([
                    {
                        prefixth: "นาย",
                        prefixen: "Mr."

                    },
                    {
                        prefixth: "นาง",
                        prefixen: "Mrs."

                    },
                    {
                        prefixth: "นางสาว",
                        prefixen: "Ms."

                    },
                ]);

            })

        });

};
