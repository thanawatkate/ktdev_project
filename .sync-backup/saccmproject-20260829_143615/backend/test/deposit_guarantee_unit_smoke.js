/**
 * Smoke tests สำหรับสิทธิ์ทะเบียนเงินประกัน (ไม่ต้องมี DB)
 */
const assert = require('assert');
const { PERM } = require('../src/utils/register_deposit_permission.util');

const MG_GUARANTEE = 4;
const MG_TAX = 3;

function expectedMoneyGroup(depositType) {
  if (depositType === 'contract_guarantee') return MG_GUARANTEE;
  if (depositType === 'withholding_tax') return MG_TAX;
  return null;
}

function parseAmount(v) {
  const n = parseFloat(String(v ?? '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : 0;
}

assert.strictEqual(expectedMoneyGroup('contract_guarantee'), MG_GUARANTEE);
assert.strictEqual(expectedMoneyGroup('withholding_tax'), MG_TAX);
assert.strictEqual(expectedMoneyGroup('other'), null);
assert.strictEqual(parseAmount('1,234.50'), 1234.5);
assert.ok(PERM.view);
assert.ok(PERM.create);
assert.ok(PERM.settle);

console.log('deposit_guarantee_unit_smoke: PASS');
