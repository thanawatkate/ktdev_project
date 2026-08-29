#!/usr/bin/env node
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const db = require('../src/utils/db');
const { revokeLicense } = require('../src/services/license.service');

function arg(name) {
  const idx = process.argv.indexOf(`--${name}`);
  return idx === -1 || !process.argv[idx + 1] ? null : process.argv[idx + 1];
}

async function main() {
  const schoolCode = arg('school');
  if (!schoolCode) {
    console.error('ใช้: node scripts/revoke-license.js --school <school_code>');
    process.exit(1);
  }
  const result = await revokeLicense({ schoolCode, note: arg('note') });
  console.log(result.status === 'success' ? '✅' : '❌', result.message || schoolCode);
  await db.destroy();
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
