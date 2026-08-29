
/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
    // return knex.schema.createViewOrReplace('users_view', function (view) {

    return knex.schema.createView('users_view', function (view) {
        //  view.columns(['first_name']).rename('name_user');
        view.columns(['code',
            'email',
            'name',
            'lastname',
            'contactnumber',
            'created',
            'usergroupth',
            'usergroupen',
            "prefixth",
            "prefixen"]);
        view.as(knex('users')
            .join('usergroup', 'users.refusergroup', 'usergroup.id')
            .join('prefix', 'users.refprefix', 'prefix.id')
            .select('users.code',
                'users.email',
                'users.name',
                'users.lastname',
                'users.contactnumber',
                'users.created',
                'usergroup.nameth',
                'usergroup.nameen',
                "prefix.prefixth",
                "prefix.prefixen"
            ));
    })
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
    return knex.schema.dropView('users_view')
    // knex.schema.dropViewIfExists('users_view')
    //knex.schema.dropMaterializedView('users_view')
    //knex.schema.dropMaterializedViewIfExists('users_view')




};
