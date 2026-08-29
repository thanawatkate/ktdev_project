/**
 * จุดรวมสำหรับสร้าง Knex ที่ใช้รัน migration (CLI, db.init, setup route)
 * ให้ migrations.directory ตรงกับ knexfile เสมอ ไม่พึ่ง process.cwd()
 */
const knex = require('knex');
const knexfile = require('../../knexfile');

function getEnv() {
  return process.env.NODE_ENV || 'development';
}

/** Knex ตาม .env + knexfile — เรียก migrate.* แล้วต้อง destroy() */
function knexFromEnv() {
  return knex(knexfile[getEnv()]);
}

/**
 * Knex ด้วย connection ชั่วคราว (หน้าตั้งค่าในแอป) — pool เล็ก
 * @param {{ host: string, port?: number|string, user: string, password?: string, database: string }} p
 */
function knexFromCredentials(p) {
  const env = getEnv();
  const cfg = knexfile[env];
  const port = parseInt(String(p.port), 10) || 3306;
  return knex({
    client: cfg.client,
    connection: {
      host: p.host,
      port,
      user: p.user,
      password: p.password || '',
      database: p.database,
    },
    pool: { min: 1, max: 2 },
    migrations: cfg.migrations,
  });
}

module.exports = {
  getEnv,
  knexFromEnv,
  knexFromCredentials,
};
