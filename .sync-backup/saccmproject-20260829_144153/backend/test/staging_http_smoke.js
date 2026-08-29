require('dotenv').config();
const { spawn } = require('child_process');
const { assertSafeE2EDatabase } = require('./e2e_db_safety');

const smokeScripts = [
  'test/auth_boundary_http_smoke.js',
  'test/approval_http_e2e_smoke.js',
  'test/expense_http_e2e_smoke.js',
];

function isLocalHost(hostname) {
  return ['localhost', '127.0.0.1', '::1'].includes(hostname);
}

function validateStagingBaseUrl(rawUrl = process.env.E2E_BASE_URL) {
  if (!rawUrl) {
    throw new Error('E2E_BASE_URL is required for staging smoke tests.');
  }

  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch (_) {
    throw new Error('E2E_BASE_URL must be a valid URL.');
  }

  if (!parsed.pathname.replace(/\/+$/, '').endsWith('/saccapi')) {
    throw new Error('E2E_BASE_URL must point to the /saccapi base path.');
  }

  if (parsed.protocol === 'https:') return parsed.toString().replace(/\/+$/, '');

  if (
    parsed.protocol === 'http:'
    && isLocalHost(parsed.hostname)
    && process.env.ALLOW_LOCAL_STAGING_SMOKE === 'true'
  ) {
    return parsed.toString().replace(/\/+$/, '');
  }

  throw new Error(
    'E2E_BASE_URL must be https. Localhost http is only allowed with ALLOW_LOCAL_STAGING_SMOKE=true.',
  );
}

async function runNodeScript(scriptPath) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath], {
      stdio: 'inherit',
      env: process.env,
    });
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) return resolve();
      reject(new Error(`${scriptPath} failed with exit code ${code}`));
    });
  });
}

async function main() {
  const normalizedUrl = validateStagingBaseUrl();
  process.env.E2E_BASE_URL = normalizedUrl;
  assertSafeE2EDatabase();

  for (const script of smokeScripts) {
    await runNodeScript(script);
  }

  console.log('staging-http-smoke: PASS');
}

if (require.main === module) {
  main().catch((err) => {
    console.error('staging-http-smoke: FAIL');
    console.error(err.message);
    process.exit(1);
  });
}

module.exports = {
  validateStagingBaseUrl,
};
