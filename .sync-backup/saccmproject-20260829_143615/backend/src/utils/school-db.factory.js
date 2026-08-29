/**
 * สร้าง / migrate database ต่อโรงเรียน และ cache connection
 */
require('dotenv').config();
const knex = require('knex');
const knexfile = require('../../knexfile');
const ensureDatabaseExists = require('./ensure-database');

const pool = new Map();

function schoolDbName(schoolCode) {
  const safe = String(schoolCode || '')
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, '_')
    .replace(/_+/g, '_')
    .slice(0, 48);
  return `saccm_${safe}`;
}

function buildKnex(database) {
  const env = process.env.NODE_ENV || 'development';
  const cfg = knexfile[env];
  return knex({
    client: cfg.client,
    connection: {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT, 10) || 3306,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD || '',
      database,
    },
    pool: { min: 1, max: 8 },
    migrations: cfg.migrations,
  });
}

function getSchoolKnex(dbName) {
  if (!pool.has(dbName)) {
    pool.set(dbName, buildKnex(dbName));
  }
  return pool.get(dbName);
}

async function seedSchoolBasics(db) {
  const hasGroup = await db('usergroup').count('id as c').first();
  if (parseInt(hasGroup?.c, 10) > 0) return;

  await db('usergroup').insert([
    { nameth: 'ผู้ดูแลระบบ', nameen: 'admin', use: 'Y' },
    { nameth: 'เจ้าหน้าที่', nameen: 'officer', use: 'Y' },
  ]);

  const prefixExists = await db('prefix').count('id as c').first();
  if (parseInt(prefixExists?.c, 10) === 0) {
    await db('prefix').insert([
      { prefixth: 'นาย', prefixen: 'Mr.', use: 'Y' },
      { prefixth: 'นาง', prefixen: 'Mrs.', use: 'Y' },
      { prefixth: 'นางสาว', prefixen: 'Miss', use: 'Y' },
    ]);
  }
}

/**
 * สร้าง DB + migrate + seed usergroup/prefix ขั้นต่ำ
 * @returns {Promise<string>} db_name
 */
async function provisionSchoolDatabase(schoolCode) {
  const dbName = schoolDbName(schoolCode);
  await ensureDatabaseExists(dbName);
  const db = getSchoolKnex(dbName);
  await db.migrate.latest();
  await seedSchoolBasics(db);
  return dbName;
}

module.exports = {
  schoolDbName,
  getSchoolKnex,
  provisionSchoolDatabase,
  seedSchoolBasics,
};
