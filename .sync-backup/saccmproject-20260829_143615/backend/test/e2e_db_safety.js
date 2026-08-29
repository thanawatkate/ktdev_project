const SAFE_DB_NAME_PATTERN = /(^|[_-])(test|e2e|ci|staging|stage|sandbox|tmp|temp)([_-]|$)/i;

function isTrue(value) {
  return String(value || '').toLowerCase() === 'true';
}

function assertSafeE2EDatabase() {
  if (isTrue(process.env.ALLOW_E2E_NON_TEST_DB)) return;

  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'Refusing to run HTTP e2e in NODE_ENV=production. Use a disposable test/staging environment.',
    );
  }

  const dbName = process.env.DB_NAME || '';
  if (!dbName || !SAFE_DB_NAME_PATTERN.test(dbName)) {
    throw new Error(
      [
        `Refusing to run HTTP e2e against DB_NAME="${dbName || '(empty)'}".`,
        'Use a disposable database name containing test/e2e/ci/staging/sandbox/tmp,',
        'or set ALLOW_E2E_NON_TEST_DB=true for an intentional local override.',
      ].join(' '),
    );
  }
}

module.exports = {
  assertSafeE2EDatabase,
};
