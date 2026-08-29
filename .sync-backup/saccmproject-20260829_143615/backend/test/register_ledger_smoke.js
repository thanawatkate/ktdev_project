require('dotenv').config();

const requiredDbEnv = ['DB_HOST', 'DB_USER', 'DB_NAME'];
const missingDbEnv = requiredDbEnv.filter((key) => !String(process.env[key] || '').trim());

if (missingDbEnv.length > 0) {
  console.log(`register_ledger_smoke: SKIP (missing ${missingDbEnv.join(', ')})`);
  process.exit(0);
}

const assert = require('assert');
const db = require('../src/configs/db.config');
const genericRegisterService = require('../src/sacc_register/services/generic_register.service');
const { getCurrentFiscalYearBuddhist } = require('../src/utils/fiscal_year.util');

function assertLedgerShape(payload, name) {
  assert(payload && typeof payload === 'object', `${name}: response should be object`);
  assert(payload.data && typeof payload.data === 'object', `${name}: data should be object`);

  const d = payload.data;
  assert(Object.prototype.hasOwnProperty.call(d, 'opening'), `${name}: missing opening`);
  assert(Object.prototype.hasOwnProperty.call(d, 'lines'), `${name}: missing lines`);
  assert(Object.prototype.hasOwnProperty.call(d, 'ending'), `${name}: missing ending`);
  assert(Array.isArray(d.lines), `${name}: lines must be array`);
}

async function main() {
  const fiscalYear = getCurrentFiscalYearBuddhist();
  const query = { fiscal_year: String(fiscalYear) };

  const currentAccount = await genericRegisterService.getCurrentAccountRegister(query);
  assertLedgerShape(currentAccount, 'current-account');

  const agencyDeposit = await genericRegisterService.getAgencyDepositRegister(query);
  assertLedgerShape(agencyDeposit, 'agency-deposit');

  const treasuryRemit = await genericRegisterService.getTreasuryRemitRegister(query);
  assertLedgerShape(treasuryRemit, 'treasury-remit');

  console.log(
    JSON.stringify({
      status: 'ok',
      fiscal_year: fiscalYear,
      line_counts: {
        current_account: currentAccount.data.lines.length,
        agency_deposit: agencyDeposit.data.lines.length,
        treasury_remit: treasuryRemit.data.lines.length,
      },
    }),
  );
}

main()
  .then(() => db.destroy())
  .catch(async (err) => {
    console.error(err);
    await db.destroy().catch(() => {});
    process.exit(1);
  });
