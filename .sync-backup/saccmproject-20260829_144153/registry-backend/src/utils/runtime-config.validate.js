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
    normalized === 'CI-INTERNAL-SECRET' ||
    normalized === 'CI-LICENSE-ADMIN-SECRET'
  );
}

function requirePresent(errors, key) {
  if (isPlaceholder(valueOf(key))) {
    errors.push(`${key} must be configured with a real value`);
  }
}

function requireSecret(errors, key, minLength = 24) {
  const value = valueOf(key);
  if (isPlaceholder(value)) {
    errors.push(`${key} must be configured with a real secret`);
    return;
  }
  if (value.length < minLength) {
    errors.push(`${key} must be at least ${minLength} characters`);
  }
}

function validateRegistryDatabaseSeparation(errors) {
  const dbName = valueOf('DB_NAME').toLowerCase();
  const knownBackendDbs = new Set(['sacc', 'sacc_master', 'saccm_master']);
  if (
    knownBackendDbs.has(dbName) &&
    process.env.ALLOW_REGISTRY_SHARED_DB !== 'true'
  ) {
    errors.push(
      'DB_NAME points to a known backend database. Registry must use a separate database such as saccm_registry',
    );
  }
}

function validateRegistryRuntimeConfig() {
  const errors = [];
  validateRegistryDatabaseSeparation(errors);

  if (!isProduction()) {
    if (errors.length > 0) {
      throw new Error(`Invalid registry configuration:\n- ${errors.join('\n- ')}`);
    }
    return;
  }

  ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME', 'ONLINE_API_BASE'].forEach((key) => {
    requirePresent(errors, key);
  });
  requireSecret(errors, 'INTERNAL_API_SECRET', 24);
  requireSecret(errors, 'LICENSE_ADMIN_SECRET', 24);
  requireSecret(errors, 'TRIAL_SIGNING_SECRET', 24);

  if (errors.length > 0) {
    throw new Error(`Invalid production registry configuration:\n- ${errors.join('\n- ')}`);
  }
}

module.exports = {
  validateRegistryRuntimeConfig,
};
