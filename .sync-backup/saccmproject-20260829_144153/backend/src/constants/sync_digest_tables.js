/**
 * รายการคีย์ใน GET /saccapi/sync/digest — ใช้ชื่อเดียวกับตาราง SQLite ในแอป
 * (เซิร์ฟเวอร์ MySQL อาจชื่อคนละแบบ เช่น budgetsource / paycheque — แมปใน sync_digest.route.js)
 */
const SYNC_DIGEST_TABLES = [
  'income',
  'expense',
  'expensetype',
  'party',
  'budget_source_budget',
  'income_type_budget_source_map',
  'users',
  'moneytype',
  'incometype',
  'bank',
  'bankaccount',
  'chequeaccount',
  'pay_cheque',
  'member',
  'prefix',
  'usergroup',
  'docgroup',
  'moneygroup',
  'incomesub',
  'expensesub',
  'loan',
  'loansub',
  'repayloan',
  'repayloansub',
  'expensereq',
  'expensereqsub',
  'deposit_guarantee',
];

const SYNC_DIGEST_VERSION = 8;

module.exports = { SYNC_DIGEST_TABLES, SYNC_DIGEST_VERSION };
