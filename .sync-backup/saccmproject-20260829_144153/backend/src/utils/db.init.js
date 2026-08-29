/**
 * db.init.js
 * ตรวจสอบว่า database มีอยู่หรือไม่ ถ้าไม่มีให้สร้าง แล้วรัน migration ให้ครบ
 */
require('dotenv').config();
const knex = require('knex');
const knexConfig = require('../../knexfile');
const ensureDatabaseExists = require('./ensure-database');

async function runMigrations() {
  const env = process.env.NODE_ENV || 'development';
  const db = knex(knexConfig[env]);

  try {
    console.log('🔄 กำลังตรวจสอบและรัน migration...');
    const [batchNo, migrations] = await db.migrate.latest();

    if (migrations.length === 0) {
      console.log('✅ Migration ทันสมัยแล้ว ไม่มีไฟล์ใหม่');
    } else {
      console.log(`✅ Migration batch ${batchNo} สำเร็จ: ${migrations.length} ไฟล์`);
      migrations.forEach((m) => console.log(`   - ${m}`));
    }
  } finally {
    await db.destroy();
  }
}

async function initDatabase() {
  try {
    await ensureDatabaseExists();
    await runMigrations();
    console.log('🎉 Database พร้อมใช้งาน\n');
    return true;
  } catch (err) {
    console.error('❌ Database initialization ล้มเหลว:', err.message);
    console.warn('⚠️  Server จะเริ่มในโหมด Setup — เปิดแอปแล้วกด "ตั้งค่าฐานข้อมูล" เพื่อแก้ไขการเชื่อมต่อ');
    return false;
  }
}

module.exports = initDatabase;
