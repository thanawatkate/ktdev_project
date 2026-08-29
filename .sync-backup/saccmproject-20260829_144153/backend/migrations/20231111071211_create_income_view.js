
/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    // return knex.schema.createViewOrReplace('users_view', function (view) {

    return knex.schema.createView('income_view', function (view) {
        //  view.columns(['first_name']).rename('name_user');
        view.columns(['id', 'created',
            'updated',
            'docdate',
            'docno',
            'detail',
            'remark',
            'user',
            'moneytype',
            'incometype',
            "amount"]);
        view.as(knex('income')
            .join('users', 'users.code', 'income.refuser')
            .join('incomesub', 'income.id', 'incomesub.refincome')
            .join('incometype', 'incometype.id', 'incomesub.refincometype')
            .join('moneytype', 'moneytype.id', 'income.refmoneytype')
            .select('income.id',
                'income.created',
                'income.updated',
                'income.docdate',
                'income.docno',
                'income.detail',
                'income.remark',
                knex.raw(`CONCAT(users.name,\' \',users.lastname)`),
                'moneytype.name',
                "incometype.name",
                "income.amount"
            ));
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropView('income_view')
    // knex.schema.dropViewIfExists('users_view')
    //knex.schema.dropMaterializedView('users_view')
    //knex.schema.dropMaterializedViewIfExists('users_view') 
};
