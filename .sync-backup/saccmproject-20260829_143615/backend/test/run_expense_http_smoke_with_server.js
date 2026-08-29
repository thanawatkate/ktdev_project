require('dotenv').config();
const { spawn } = require('child_process');
const { assertSafeE2EDatabase } = require('./e2e_db_safety');

const BASE_URL = process.env.E2E_BASE_URL || `http://localhost:${process.env.PORT || 3800}/saccapi`;
const HEALTH_URL = `${BASE_URL}`;
const HEALTH_TIMEOUT_MS = 45000;

assertSafeE2EDatabase();

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function isServerReady() {
  try {
    const res = await fetch(HEALTH_URL);
    if (!res.ok) return false;
    const body = await res.json();
    return body && body.status === 'OK';
  } catch (_) {
    return false;
  }
}

async function waitForServerReady(timeoutMs) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await isServerReady()) return true;
    await sleep(800);
  }
  return false;
}

function runNodeScript(scriptPath) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath], {
      stdio: 'inherit',
      env: process.env,
    });
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) return resolve();
      reject(new Error(`Script failed with exit code ${code}`));
    });
  });
}

async function main() {
  let spawnedServer = null;
  let startedByScript = false;
  try {
    const alreadyReady = await isServerReady();
    if (!alreadyReady) {
      startedByScript = true;
      spawnedServer = spawn(process.execPath, ['index.js'], {
        cwd: process.cwd(),
        stdio: 'inherit',
        env: process.env,
      });
      const ready = await waitForServerReady(HEALTH_TIMEOUT_MS);
      if (!ready) {
        throw new Error('Server did not become ready in time');
      }
    }

    await runNodeScript('test/expense_http_e2e_smoke.js');
    console.log('expense-http-e2e-with-server: PASS');
  } finally {
    if (startedByScript && spawnedServer && !spawnedServer.killed) {
      spawnedServer.kill('SIGTERM');
    }
  }
}

main().catch((err) => {
  console.error('expense-http-e2e-with-server: FAIL');
  console.error(err.message);
  process.exit(1);
});
