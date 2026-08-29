/**
 * Tier B — Server-anchored trial.
 * ผูกวันเริ่มทดลองใช้ไว้กับ fingerprint ของเครื่องบน Registry
 * เพื่อกัน reset (ลบ app data) และ reinstall จาก client.
 */
exports.up = async function (knex) {
  await knex.schema.createTable('trial_registration', (t) => {
    t.increments('id').primary();
    t.string('fingerprint', 128).notNullable().unique();
    t.string('platform', 32).nullable();
    t.timestamp('trial_started_at').notNullable().defaultTo(knex.fn.now());
    t.integer('trial_days').unsigned().notNullable().defaultTo(90);
    t.timestamp('last_seen').nullable();
    t.string('client_ip', 45).nullable();
    t.timestamp('created').defaultTo(knex.fn.now());
  });
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('trial_registration');
};
