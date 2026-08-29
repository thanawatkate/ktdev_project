function isProduction() {
  return process.env.NODE_ENV === 'production';
}

function valueOf(key) {
  return String(process.env[key] || '').trim();
}

function isPlaceholder(value) {
  const normalized = String(value || '').trim().toUpperCase();
  return (
    normalized === '' ||
    normalized.includes('CHANGE_ME') ||
    normalized.includes('PLACEHOLDER') ||
    normalized.includes('YOUR_') ||
    normalized === 'CI-TEST-SECRET' ||
    normalized === 'CI-INTERNAL-SECRET'
  );
}

function requirePresent(errors, key) {
  if (isPlaceholder(valueOf(key))) {
    errors.push(`${key} must be configured with a real value`);
  }
}

function requireSecret(errors, key, minLength = 32) {
  const value = valueOf(key);
  if (isPlaceholder(value)) {
    errors.push(`${key} must be configured with a real secret`);
    return;
  }
  if (value.length < minLength) {
    errors.push(`${key} must be at least ${minLength} characters`);
  }
}

function validateBackendRuntimeConfig() {
  if (!isProduction()) return;

  const errors = [];
  ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'].forEach((key) => {
    requirePresent(errors, key);
  });
  requireSecret(errors, 'SECRETKEY', 32);
  requireSecret(errors, 'INTERNAL_API_SECRET', 24);

  if (process.env.ENABLE_SETUP_ROUTES === 'true') {
    requireSecret(errors, 'SETUP_API_SECRET', 24);
  }

  if (errors.length > 0) {
    throw new Error(`Invalid production backend configuration:\n- ${errors.join('\n- ')}`);
  }
}

module.exports = {
  validateBackendRuntimeConfig,
};
