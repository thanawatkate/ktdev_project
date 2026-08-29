#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const BACKEND_KNOWN_DBS = new Set(['sacc', 'sacc_master', 'saccm_master']);
const PLACEHOLDER_PARTS = ['CHANGE_ME', 'PLACEHOLDER', 'YOUR_'];

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const current = argv[i];
    if (!current.startsWith('--')) continue;
    const key = current.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      i += 1;
    }
  }
  return args;
}

function parseEnvFile(filePath) {
  const env = {};
  const text = fs.readFileSync(filePath, 'utf8');
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"'))
      || (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }
  return env;
}

function value(env, key) {
  return String(env[key] || '').trim();
}

function isPlaceholder(raw) {
  const normalized = String(raw || '').trim().toUpperCase();
  return (
    normalized === ''
    || PLACEHOLDER_PARTS.some((part) => normalized.includes(part))
  );
}

function requirePresent(errors, env, key, label) {
  if (isPlaceholder(value(env, key))) {
    errors.push(`${label}: ${key} must be configured with a real value`);
  }
}

function requireSecret(errors, env, key, minLength, label) {
  const raw = value(env, key);
  if (isPlaceholder(raw)) {
    errors.push(`${label}: ${key} must be configured with a real secret`);
    return;
  }
  if (raw.length < minLength) {
    errors.push(`${label}: ${key} must be at least ${minLength} characters`);
  }
}

function isHttpsOrLocalhostUrl(raw) {
  try {
    const parsed = new URL(raw);
    if (parsed.protocol === 'https:') return true;
    return parsed.protocol === 'http:' && ['localhost', '127.0.0.1', '::1'].includes(parsed.hostname);
  } catch (_) {
    return false;
  }
}

function validateCors(errors, warnings, env, label) {
  const cors = value(env, 'CORS_ORIGIN');
  if (isPlaceholder(cors) || cors === '*') {
    errors.push(`${label}: CORS_ORIGIN must list trusted origins, not wildcard/placeholders`);
    return;
  }
  for (const origin of cors.split(',').map((part) => part.trim()).filter(Boolean)) {
    if (!isHttpsOrLocalhostUrl(origin)) {
      errors.push(`${label}: CORS_ORIGIN entry must be https or localhost: ${origin}`);
    }
  }
  if (value(env, 'TRUST_PROXY') !== 'true') {
    warnings.push(`${label}: TRUST_PROXY is not true; set it when running behind a reverse proxy`);
  }
}

function validateDbUser(errors, warnings, env, label) {
  const user = value(env, 'DB_USER').toLowerCase();
  if (user === 'root') {
    errors.push(`${label}: DB_USER must not be root in production`);
  } else if (!user) {
    errors.push(`${label}: DB_USER must be configured`);
  }
  if (value(env, 'DB_PASSWORD').length < 12) {
    warnings.push(`${label}: DB_PASSWORD is short; use a strong unique database password`);
  }
}

function validateBackend(env) {
  const errors = [];
  const warnings = [];
  const label = 'backend';

  if (value(env, 'NODE_ENV') !== 'production') {
    errors.push(`${label}: NODE_ENV must be production`);
  }
  ['DB_HOST', 'DB_NAME'].forEach((key) => requirePresent(errors, env, key, label));
  validateDbUser(errors, warnings, env, label);
  requireSecret(errors, env, 'SECRETKEY', 32, label);
  requireSecret(errors, env, 'INTERNAL_API_SECRET', 24, label);
  if (value(env, 'ENABLE_SETUP_ROUTES') === 'true') {
    requireSecret(errors, env, 'SETUP_API_SECRET', 24, label);
    warnings.push(`${label}: ENABLE_SETUP_ROUTES=true should only be temporary`);
  }
  if (value(env, 'ALLOW_DEFAULT_CREDENTIALS') === 'true') {
    errors.push(`${label}: ALLOW_DEFAULT_CREDENTIALS must not be true in production`);
  }
  validateCors(errors, warnings, env, label);

  return { errors, warnings };
}

function validateRegistry(env, backendEnv) {
  const errors = [];
  const warnings = [];
  const label = 'registry';

  if (value(env, 'NODE_ENV') !== 'production') {
    errors.push(`${label}: NODE_ENV must be production`);
  }
  ['DB_HOST', 'DB_NAME', 'ONLINE_API_BASE'].forEach((key) => requirePresent(errors, env, key, label));
  validateDbUser(errors, warnings, env, label);
  requireSecret(errors, env, 'INTERNAL_API_SECRET', 24, label);
  requireSecret(errors, env, 'LICENSE_ADMIN_SECRET', 24, label);
  requireSecret(errors, env, 'TRIAL_SIGNING_SECRET', 24, label);

  const registryDb = value(env, 'DB_NAME').toLowerCase();
  const backendDb = value(backendEnv, 'DB_NAME').toLowerCase();
  if (BACKEND_KNOWN_DBS.has(registryDb) || registryDb === backendDb) {
    errors.push(`${label}: DB_NAME must be separate from the backend database`);
  }
  if (value(env, 'INTERNAL_API_SECRET') !== value(backendEnv, 'INTERNAL_API_SECRET')) {
    errors.push(`${label}: INTERNAL_API_SECRET must match backend INTERNAL_API_SECRET`);
  }
  if (!isHttpsOrLocalhostUrl(value(env, 'ONLINE_API_BASE'))) {
    errors.push(`${label}: ONLINE_API_BASE must be https or localhost`);
  }
  validateCors(errors, warnings, env, label);

  return { errors, warnings };
}

function resolveDefault(relativePath) {
  return path.resolve(__dirname, '../..', relativePath);
}

function run(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  const backendEnvPath = path.resolve(args['backend-env'] || resolveDefault('backend/.env'));
  const registryEnvPath = path.resolve(args['registry-env'] || resolveDefault('registry-backend/.env'));

  const errors = [];
  const warnings = [];

  for (const filePath of [backendEnvPath, registryEnvPath]) {
    if (!fs.existsSync(filePath)) {
      errors.push(`missing env file: ${filePath}`);
    }
  }

  if (errors.length === 0) {
    const backendEnv = parseEnvFile(backendEnvPath);
    const registryEnv = parseEnvFile(registryEnvPath);
    const backendResult = validateBackend(backendEnv);
    const registryResult = validateRegistry(registryEnv, backendEnv);
    errors.push(...backendResult.errors, ...registryResult.errors);
    warnings.push(...backendResult.warnings, ...registryResult.warnings);
  }

  if (warnings.length > 0) {
    console.warn('production-config-preflight: WARN');
    for (const warning of warnings) console.warn(`- ${warning}`);
  }

  if (errors.length > 0) {
    console.error('production-config-preflight: FAIL');
    for (const error of errors) console.error(`- ${error}`);
    return 1;
  }

  console.log('production-config-preflight: PASS');
  return 0;
}

if (require.main === module) {
  process.exit(run());
}

module.exports = {
  parseEnvFile,
  validateBackend,
  validateRegistry,
  run,
};
