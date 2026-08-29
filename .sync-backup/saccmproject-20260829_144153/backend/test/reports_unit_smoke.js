const assert = require('assert');

process.env.SECRETKEY = process.env.SECRETKEY || 'reports-test-secret';

const {
  groupExpenseRowsByOfficialSection,
  parseReportDate,
  parseReportFiscalYear,
} = require('../src/sacc_reports/services/extra_reports.service');
const { requireReportAccess } = require('../src/middleware/report-auth.middleware');

function testExpenseGrouping() {
  const grouped = groupExpenseRowsByOfficialSection([
    { code: '00', type_name: 'ค่าจ้าง', total: '100', count: '1' },
    { code: '01', type_name: 'ค่าตอบแทน', total: '10', count: '1' },
    { code: '04', type_name: 'ค่าสาธารณูปโภค', total: '20', count: '2' },
    { code: '05', type_name: 'ครุภัณฑ์', total: '30', count: '1' },
    { code: '07', type_name: 'เงินอุดหนุน', total: '40', count: '1' },
    { code: '08', type_name: 'อื่น', total: '50', count: '1' },
  ]);

  assert.deepStrictEqual(
    grouped.map((r) => r.code),
    ['personnel', 'operating', 'investment', 'subsidy', 'other'],
  );
  assert.strictEqual(grouped.find((r) => r.code === 'operating').total, 30);
  assert.strictEqual(grouped.find((r) => r.code === 'operating').count, 3);
}

function testQueryValidation() {
  assert.strictEqual(parseReportDate('2026-05-25'), '2026-05-25');
  assert.strictEqual(parseReportFiscalYear('2569'), 2569);
  assert.throws(() => parseReportDate('25/05/2026'), /YYYY-MM-DD/);
  assert.throws(() => parseReportFiscalYear('2026'), /2500-2700/);
}

async function testMissingReportTokenRejected() {
  let statusCode = null;
  let payload = null;
  await requireReportAccess(
    { headers: {}, query: {}, body: {} },
    {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        payload = data;
        return this;
      },
    },
    (err) => {
      if (err) throw err;
      throw new Error('next should not be called for missing token');
    },
  );

  assert.strictEqual(statusCode, 401);
  assert.strictEqual(payload.success, false);
}

async function main() {
  testExpenseGrouping();
  testQueryValidation();
  await testMissingReportTokenRejected();
  console.log('reports_unit_smoke: PASS');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
