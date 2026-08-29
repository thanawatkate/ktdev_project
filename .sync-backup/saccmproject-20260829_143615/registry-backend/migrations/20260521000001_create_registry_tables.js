/**
 * Registry กลาง — keygen, license, activation log (แยกจาก DB ระบบออนไลน์)
 */
exports.up = async function (knex) {
  await knex.schema.createTable('school_license', (t) => {
    t.increments('id').primary();
    t.string('school_code', 32).notNullable().unique();
    t.string('school_name', 255).notNullable();
    t.string('license_key_hash', 255).notNullable();
    t.string('db_name', 64).notNullable().unique();
    t.enu('license_kind', ['offline', 'online'], {
      useNative: true,
      existingType: false,
      enumName: 'registry_license_kind_enum',
    }).notNullable().defaultTo('offline');
    t.enu('status', ['pending', 'active', 'revoked', 'expired'], {
      useNative: true,
      existingType: false,
      enumName: 'registry_license_status_enum',
    }).notNullable().defaultTo('pending');
    t.integer('max_devices').unsigned().notNullable().defaultTo(3);
    t.timestamp('expires_at').nullable();
    t.timestamp('activated_at').nullable();
    t.text('note').nullable();
    t.string('issued_by', 128).nullable();
    t.string('key_hint', 16).nullable().comment('เช่น ...-AB12 ไม่เก็บรหัสเต็ม');
    t.timestamp('created').defaultTo(knex.fn.now());
    t.timestamp('updated').defaultTo(knex.fn.now());
  });

  await knex.schema.createTable('license_issue_log', (t) => {
    t.increments('id').primary();
    t.integer('ref_school_license')
      .unsigned()
      .references('id')
      .inTable('school_license')
      .onDelete('CASCADE');
    t.string('school_code', 32).notNullable();
    t.string('school_name', 255).notNullable();
    t.enu('license_kind', ['offline', 'online'], {
      useNative: true,
      existingType: true,
      enumName: 'registry_license_kind_enum',
    }).notNullable();
    t.integer('max_devices').unsigned().notNullable();
    t.timestamp('expires_at').nullable();
    t.string('issued_by', 128).nullable();
    t.string('key_hint', 16).nullable();
    t.text('note').nullable();
    t.timestamp('created').defaultTo(knex.fn.now());
  });

  await knex.schema.createTable('license_activation_log', (t) => {
    t.increments('id').primary();
    t.integer('ref_school_license')
      .unsigned()
      .nullable()
      .references('id')
      .inTable('school_license')
      .onDelete('SET NULL');
    t.string('school_code', 32).nullable();
    t.string('device_id', 64).nullable();
    t.string('platform', 32).nullable();
    t.enu('event', ['activate_success', 'activate_fail', 'heartbeat', 'validate'], {
      useNative: true,
      existingType: false,
      enumName: 'registry_activation_event_enum',
    }).notNullable();
    t.string('result', 16).nullable().comment('success|fail');
    t.text('message').nullable();
    t.string('client_ip', 45).nullable();
    t.timestamp('created').defaultTo(knex.fn.now());
  });

  await knex.schema.createTable('school_device', (t) => {
    t.increments('id').primary();
    t.integer('ref_school_license')
      .unsigned()
      .notNullable()
      .references('id')
      .inTable('school_license')
      .onUpdate('CASCADE')
      .onDelete('CASCADE');
    t.string('device_id', 64).notNullable();
    t.string('device_label', 128).nullable();
    t.string('platform', 32).nullable();
    t.timestamp('first_seen').defaultTo(knex.fn.now());
    t.timestamp('last_seen').defaultTo(knex.fn.now());
    t.unique(['ref_school_license', 'device_id']);
  });
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('school_device');
  await knex.schema.dropTableIfExists('license_activation_log');
  await knex.schema.dropTableIfExists('license_issue_log');
  await knex.schema.dropTableIfExists('school_license');
};
