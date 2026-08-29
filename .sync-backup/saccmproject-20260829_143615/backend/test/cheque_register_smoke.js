const assert = require('assert');
const genericRegisterService = require('../src/sacc_register/services/generic_register.service');
const { getCurrentFiscalYearBuddhist } = require('../src/utils/fiscal_year.util');

async function main() {
  const fiscalYear = getCurrentFiscalYearBuddhist();
  const result = await genericRegisterService.getChequeRegister({
    fiscal_year: String(fiscalYear),
  });

  assert(result && typeof result === 'object', 'response should be object');
  assert(Array.isArray(result.data), 'data must be array');
  if (result.data.length > 0) {
    const row = result.data[0];
    assert('docdate' in row, 'row missing docdate');
    assert('amount' in row || 'chequeamount' in row, 'row missing amount');
  }

  console.log(
    JSON.stringify({
      status: 'ok',
      fiscal_year: fiscalYear,
      row_count: result.data.length,
    }),
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
