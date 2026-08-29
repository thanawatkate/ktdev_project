/**
 * แมปโรงเรียน → DB บนระบบออนไลน์ (สร้างจาก Registry ผ่าน internal/provision เท่านั้น)
 * ไม่เก็บรหัส license / device — ดู registry-backend
 */
exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('school_tenant');
  if (exists) return;

  await knex.schema.createTable('school_tenant', (t) => {
    t.increments('id').primary();
    t.string('school_code', 32).notNullable().unique();
    t.string('school_name', 255).notNullable();
    t.string('db_name', 64).notNullable().unique();
    t.enu('status', ['active', 'suspended']).notNullable().defaultTo('active');
    t.timestamp('provisioned_at').defaultTo(knex.fn.now());
    t.timestamp('updated').defaultTo(knex.fn.now());
  });
};

exports.down = function (knex) {
  return knex.schema.dropTableIfExists('school_tenant');
};
