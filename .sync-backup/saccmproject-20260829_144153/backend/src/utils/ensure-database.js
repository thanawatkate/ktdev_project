/**
 * สร้าง schema ตามชื่อ database ถ้ายังไม่มี
 * @param {string} [dbName] — ค่าเริ่มต้นจาก process.env.DB_NAME
 */
require('dotenv').config();
const mysql = require('mysql2/promise');

async function ensureDatabaseExists(dbName) {
  const target = (dbName || process.env.DB_NAME || '').trim();
  if (!target) {
    throw new Error('DB_NAME ไม่ได้ตั้งใน .env');
  }
  if (!process.env.DB_USER) {
    throw new Error('DB_USER ไม่ได้ตั้งใน .env');
  }

  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD || '',
    port: parseInt(process.env.DB_PORT, 10) || 3306,
  });

  try {
    const [rows] = await conn.query(
      'SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = ?',
      [target],
    );

    if (rows.length === 0) {
      console.log(`📦 Database "${target}" ไม่พบ กำลังสร้าง...`);
      await conn.query(
        `CREATE DATABASE \`${target.replace(/`/g, '``')}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
      );
      console.log(`✅ สร้าง Database "${target}" สำเร็จ`);
    } else {
      console.log(`✅ Database "${target}" พบแล้ว`);
    }
  } finally {
    await conn.end();
  }

  return target;
}

if (require.main === module) {
  ensureDatabaseExists()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('❌', err.message);
      process.exit(1);
    });
}

module.exports = ensureDatabaseExists;
