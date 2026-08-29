require('dotenv').config();

const BASE_URL = process.env.E2E_BASE_URL || `http://localhost:${process.env.PORT || 3800}/saccapi`;

const protectedChecks = [
  { method: 'GET', path: '/expense', name: 'expense list' },
  { method: 'GET', path: '/approval', name: 'approval list' },
  { method: 'GET', path: '/finance-compliance/alerts?date=2026-05-25', name: 'finance compliance alerts' },
  { method: 'GET', path: '/reports/summary', name: 'reports summary' },
];

async function request(path, options = {}) {
  return fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: {
      Accept: 'application/json',
      ...(options.headers || {}),
    },
  });
}

async function expectStatus({ method, path, name }, headers, expectedStatus, label) {
  const res = await request(path, { method, headers });
  if (res.status !== expectedStatus) {
    const body = await res.text().catch(() => '');
    throw new Error(`${name} ${label}: expected ${expectedStatus}, got ${res.status}. ${body}`);
  }
}

async function main() {
  const health = await request('');
  if (!health.ok) {
    throw new Error(`health check failed: ${health.status}`);
  }

  for (const check of protectedChecks) {
    await expectStatus(check, {}, 401, 'without token');
    await expectStatus(check, { Authorization: 'Bearer invalid-token' }, 401, 'with invalid token');
  }

  console.log('auth-boundary-http-smoke: PASS');
}

main().catch((err) => {
  console.error('auth-boundary-http-smoke: FAIL');
  console.error(err.message);
  process.exit(1);
});
