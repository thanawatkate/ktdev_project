const express = require('express');
const router = express.Router();
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
const { knexFromEnv, knexFromCredentials } = require('../utils/knex-migrate');

const ENV_PATH = path.resolve(__dirname, '../../.env');

function setupSecret() {
  return process.env.SETUP_API_SECRET || process.env.INTERNAL_API_SECRET || '';
}

function requireSetupAccess(req, res, next) {
  if (process.env.NODE_ENV !== 'production') {
    return next();
  }

  if (process.env.ENABLE_SETUP_ROUTES !== 'true') {
    return res.status(404).json({
      success: false,
      message: 'Setup API is disabled in production',
    });
  }

  const expected = setupSecret();
  const provided = req.headers['x-setup-secret'] || req.headers['x-internal-secret'];
  if (!expected || provided !== expected) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized setup access',
    });
  }
  return next();
}

function quoteIdentifier(value) {
  const text = String(value || '').trim();
  if (!/^[A-Za-z0-9_$-]+$/.test(text)) {
    throw new Error('ชื่อฐานข้อมูลต้องใช้เฉพาะตัวอักษร ตัวเลข _ - หรือ $');
  }
  return `\`${text.replace(/`/g, '``')}\``;
}

router.use(requireSetupAccess);

// ─── Helper: write/update .env file ────────────────────────────────
function writeEnvConfig(updates) {
  let content = '';
  try { content = fs.readFileSync(ENV_PATH, 'utf8'); } catch (_) {}

  const lines = content.split('\n');
  const result = [];
  const written = new Set();

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) { result.push(line); continue; }
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) { result.push(line); continue; }
    const key = trimmed.substring(0, eqIdx).trim();
    if (Object.prototype.hasOwnProperty.call(updates, key)) {
      if (!written.has(key)) {
        result.push(`${key}="${updates[key]}"`);
        written.add(key);
      }
    } else {
      result.push(line);
    }
  }
  for (const [key, value] of Object.entries(updates)) {
    if (!written.has(key)) result.push(`${key}="${value}"`);
  }
  fs.writeFileSync(ENV_PATH, result.join('\n'), 'utf8');
}

// ────────────────────────────────────────────────────────────────────
// GET /saccapi/setup/ping — ตรวจสอบว่า API ทำงานอยู่
// ────────────────────────────────────────────────────────────────────
router.get('/ping', (req, res) => {
  res.json({
    success: true,
    message: 'API พร้อมใช้งาน',
    version: process.env.npm_package_version || '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// ────────────────────────────────────────────────────────────────────
// POST /saccapi/setup/create-db
// Body: { host, port, rootUser, rootPassword, dbName, appUser?, appPassword? }
// เชื่อมต่อด้วย root → สร้าง DB + สร้าง App User (ถ้ากรอก)
// ────────────────────────────────────────────────────────────────────
router.post('/create-db', async (req, res) => {
  const { host, port, rootUser, rootPassword, dbName, appUser, appPassword } = req.body;

  if (!host || !rootUser || !dbName) {
    return res.status(400).json({
      success: false,
      message: 'กรุณากรอก host, rootUser และ dbName',
    });
  }

  let conn;
  try {
    conn = await mysql.createConnection({
      host,
      port: parseInt(port) || 3306,
      user: rootUser,
      password: rootPassword || '',
    });

    // สร้าง Database
    const [rows] = await conn.query(
      'SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = ?',
      [dbName]
    );
    const dbCreated = rows.length === 0;
    if (dbCreated) {
      await conn.query(
        `CREATE DATABASE ${quoteIdentifier(dbName)} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`
      );
    }

    // สร้าง App User (ถ้ากรอก)
    let userCreated = false;
    if (appUser && appPassword) {
      const [userRows] = await conn.query(
        `SELECT User FROM mysql.user WHERE User = ? AND Host = '%'`,
        [appUser]
      );
      if (userRows.length === 0) {
        await conn.query(`CREATE USER ?@'%' IDENTIFIED BY ?`, [appUser, appPassword]);
        userCreated = true;
      }
      await conn.query(
        `GRANT ALL PRIVILEGES ON ${quoteIdentifier(dbName)}.* TO ?@'%'`,
        [appUser]
      );
      await conn.query('FLUSH PRIVILEGES');
    }

    return res.json({
      success: true,
      dbCreated,
      userCreated,
      message: [
        dbCreated ? `สร้าง Database "${dbName}" สำเร็จ` : `Database "${dbName}" มีอยู่แล้ว`,
        userCreated ? `สร้าง User "${appUser}" สำเร็จ` : (appUser ? `User "${appUser}" มีอยู่แล้ว (อัปสิทธิ์แล้ว)` : ''),
      ].filter(Boolean).join(' | '),
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: `ล้มเหลว: ${err.message}`,
    });
  } finally {
    if (conn) await conn.end().catch(() => {});
  }
});

// ────────────────────────────────────────────────────────────────────
// POST /saccapi/setup/migrate
// Body: { host, port, user, password, dbName }
// รัน migration ทั้งหมด → บันทึก .env → restart
// ────────────────────────────────────────────────────────────────────
router.post('/migrate', async (req, res) => {
  const { host, port, user, password, dbName } = req.body;

  if (!host || !user || !dbName) {
    return res.status(400).json({
      success: false,
      message: 'กรุณากรอก host, user และ dbName',
    });
  }

  const db = knexFromCredentials({
    host,
    port: parseInt(port, 10) || 3306,
    user,
    password,
    database: dbName,
  });

  let batchNo;
  let migrations;
  try {
    [batchNo, migrations] = await db.migrate.latest();
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: `Migration ล้มเหลว: ${err.message}`,
    });
  } finally {
    await db.destroy().catch(() => {});
  }

  // บันทึก config ลง .env
  try {
    writeEnvConfig({ DB_HOST: host, DB_PORT: String(parseInt(port) || 3306), DB_USER: user, DB_PASSWORD: password || '', DB_NAME: dbName });
    process.env.DB_HOST = host;
    process.env.DB_PORT = String(parseInt(port) || 3306);
    process.env.DB_USER = user;
    process.env.DB_PASSWORD = password || '';
    process.env.DB_NAME = dbName;
    console.log('✅ บันทึก config ลง .env สำเร็จ');
  } catch (err) {
    console.error('⚠️ บันทึก .env ไม่ได้:', err.message);
    return res.json({
      success: true,
      configSaved: false,
      restarting: false,
      message: `Migration สำเร็จ ${migrations.length} ไฟล์ แต่บันทึก config ไม่ได้: ${err.message}`,
      migrations,
    });
  }

  res.json({
    success: true,
    configSaved: true,
    restarting: true,
    message:
      migrations.length === 0
        ? 'ไม่มี Migration ใหม่ — Database ทันสมัยแล้ว'
        : `สร้างตาราง ${migrations.length} รายการ (batch ${batchNo}) สำเร็จ`,
    migrations,
  });

  setTimeout(() => {
    console.log('🔄 Restarting server...');
    process.exit(0);
  }, 400);
});

// ────────────────────────────────────────────────────────────────────
// POST /saccapi/setup/init (backward compat)
// ────────────────────────────────────────────────────────────────────
router.post('/init', async (req, res) => {
  const { host, port, user, password, dbName } = req.body;
  if (!host || !user || !dbName) {
    return res.status(400).json({ success: false, message: 'กรุณากรอก host, user และ dbName' });
  }
  let conn;
  try {
    conn = await mysql.createConnection({ host, port: parseInt(port) || 3306, user, password: password || '' });
    const [rows] = await conn.query('SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = ?', [dbName]);
    if (rows.length === 0) {
      await conn.query(`CREATE DATABASE ${quoteIdentifier(dbName)} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    }
  } catch (err) {
    if (conn) await conn.end().catch(() => {});
    return res.status(500).json({ success: false, message: `ล้มเหลว: ${err.message}` });
  }
  await conn.end().catch(() => {});

  const db = knexFromCredentials({
    host,
    port: parseInt(port, 10) || 3306,
    user,
    password,
    database: dbName,
  });
  let batchNo;
  let migrations;
  try {
    [batchNo, migrations] = await db.migrate.latest();
  } catch (err) {
    return res.status(500).json({ success: false, message: `Migration ล้มเหลว: ${err.message}` });
  } finally {
    await db.destroy().catch(() => {});
  }
  try {
    writeEnvConfig({ DB_HOST: host, DB_PORT: String(parseInt(port) || 3306), DB_USER: user, DB_PASSWORD: password || '', DB_NAME: dbName });
    process.env.DB_HOST = host; process.env.DB_PORT = String(parseInt(port) || 3306); process.env.DB_USER = user; process.env.DB_PASSWORD = password || ''; process.env.DB_NAME = dbName;
  } catch (_) {}
  res.json({ success: true, configSaved: true, restarting: true, message: `Migration สำเร็จ ${migrations.length} ไฟล์`, migrations });
  setTimeout(() => process.exit(0), 400);
});

// ────────────────────────────────────────────────────────────────────
// GET /saccapi/setup/status
// ────────────────────────────────────────────────────────────────────
router.get('/status', async (req, res) => {
  const db = knexFromEnv();
  try {
    // Knex: [รายการที่รันแล้วจาก DB, รายการที่ยังไม่รันจากโฟลเดอร์]
    const [completed, pending] = await db.migrate.list();
    return res.json({
      success: true,
      pendingCount: pending.length,
      completedCount: completed.length,
      pendingFiles: pending.map((m) => m.file),
      ready: pending.length === 0,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  } finally {
    await db.destroy().catch(() => {});
  }
});

module.exports = router;
