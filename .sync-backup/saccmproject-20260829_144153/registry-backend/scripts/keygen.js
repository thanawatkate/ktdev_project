#!/usr/bin/env node
/**
 * ออกรหัส Registry — แพ็กเกจ offline | online
 * (ทดลองใช้ = ฝังในแอป Flutter kEmbeddedTrialDays)
 */
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const ensureDatabaseExists = require('../src/utils/ensure-database');
const db = require('../src/utils/db');
const { validateRegistryRuntimeConfig } = require('../src/utils/runtime-config.validate');
const { generateLicense, STANDARD_DAYS_DEFAULT } = require('../src/services/license.service');

function arg(name, fallback) {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1) return fallback;
  if (process.argv[idx + 1] && !process.argv[idx + 1].startsWith('--')) {
    return process.argv[idx + 1];
  }
  return fallback === undefined ? true : fallback;
}

function positionalSchoolName() {
  const optionValueFlags = new Set(['--name', '--devices', '--days', '--by', '--note']);
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i += 1) {
    const item = args[i];
    if (item.startsWith('--')) {
      if (optionValueFlags.has(item)) i += 1;
      continue;
    }
    return item;
  }
  return null;
}

async function main() {
  const schoolName = arg('name', null) || positionalSchoolName();
  const isOnline = process.argv.includes('--online');
  const devices = parseInt(arg('devices', '3'), 10);
  const daysArg = arg('days', null);
  const issuedBy = arg('by', process.env.KEYGEN_ISSUED_BY || 'cli');
  const note = arg('note', '');

  if (!schoolName) {
    console.error(`
ใช้:
  node scripts/keygen.js --name "ชื่อโรงเรียน" [--offline|--online] [--devices 3] [--days 365]
  node scripts/keygen.js "ชื่อโรงเรียน" [--offline|--online] [--devices 3] [--days 365]

ค่าเริ่มต้น: ออฟไลน์ (offline) ${STANDARD_DAYS_DEFAULT} วัน
`);
    process.exit(1);
  }

  validateRegistryRuntimeConfig();
  await ensureDatabaseExists();
  await db.migrate.latest();

  const licenseKind = isOnline ? 'online' : 'offline';
  const expiresInDays = daysArg != null
    ? parseInt(daysArg, 10)
    : STANDARD_DAYS_DEFAULT;

  const result = await generateLicense({
    schoolName,
    maxDevices: devices,
    expiresInDays,
    licenseKind,
    note,
    issuedBy,
  });

  if (result.status !== 'success') {
    console.error('❌', result.message);
    process.exit(1);
  }

  console.log('\n✅ บันทึกที่ Registry แล้ว\n');
  console.log('แพ็กเกจ :', licenseKind === 'online' ? 'ออนไลน์+ออฟไลน์' : 'ออฟไลน์');
  console.log('โรงเรียน :', result.schoolName);
  console.log('schoolCode:', result.schoolCode);
  console.log('หมดอายุ :', result.expiresAt ? result.expiresAt.toISOString().slice(0, 10) : '-');
  console.log('\n── รหัส ──');
  console.log(result.licenseKey);
  console.log('');
  await db.destroy();
}

main().catch(async (e) => {
  console.error('❌', e.message);
  await db.destroy().catch(() => {});
  process.exit(1);
});
