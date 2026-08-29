#!/usr/bin/env node

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

function isLocalHost(hostname) {
  return ['localhost', '127.0.0.1', '::1'].includes(hostname);
}

function normalizeBaseUrl(rawUrl, expectedPath, label, allowLocalhost = false) {
  if (!rawUrl) throw new Error(`${label}: URL is required`);

  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch (_) {
    throw new Error(`${label}: URL must be valid`);
  }

  if (parsed.protocol !== 'https:') {
    const isAllowedLocal = parsed.protocol === 'http:' && allowLocalhost && isLocalHost(parsed.hostname);
    if (!isAllowedLocal) {
      throw new Error(`${label}: URL must use https`);
    }
  }

  const pathname = parsed.pathname.replace(/\/+$/, '');
  if (pathname !== expectedPath) {
    throw new Error(`${label}: URL must point to ${expectedPath}`);
  }

  return parsed.toString().replace(/\/+$/, '');
}

function requireSecurityHeaders(errors, headers, label) {
  const required = [
    'x-content-type-options',
    'x-frame-options',
    'referrer-policy',
  ];

  for (const header of required) {
    if (!headers.get(header)) {
      errors.push(`${label}: missing security header ${header}`);
    }
  }

  const hsts = headers.get('strict-transport-security');
  if (!hsts) {
    errors.push(`${label}: missing strict-transport-security header`);
  }
}

function validateCorsHeader(errors, headers, label, expectedOrigin) {
  const allowOrigin = headers.get('access-control-allow-origin');
  if (allowOrigin === '*') {
    errors.push(`${label}: access-control-allow-origin must not be wildcard`);
  }
  if (expectedOrigin && allowOrigin && allowOrigin !== expectedOrigin) {
    errors.push(`${label}: access-control-allow-origin "${allowOrigin}" does not match "${expectedOrigin}"`);
  }
}

async function checkEndpoint({ url, label, expectedStatus, expectedMarker, origin }) {
  const errors = [];
  const headers = origin ? { Origin: origin, Accept: 'application/json' } : { Accept: 'application/json' };
  const res = await fetch(url, { headers });

  if (res.status !== expectedStatus) {
    errors.push(`${label}: expected HTTP ${expectedStatus}, got ${res.status}`);
  }

  const contentType = res.headers.get('content-type') || '';
  if (!contentType.includes('application/json')) {
    errors.push(`${label}: expected JSON response`);
  }

  let body = null;
  try {
    body = await res.json();
  } catch (_) {
    errors.push(`${label}: response body is not valid JSON`);
  }

  if (body && body.status !== expectedMarker) {
    errors.push(`${label}: expected body.status="${expectedMarker}"`);
  }

  requireSecurityHeaders(errors, res.headers, label);
  validateCorsHeader(errors, res.headers, label, origin);

  return errors;
}

async function run(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  const allowLocalhost = args['allow-localhost'] === true || args['allow-localhost'] === 'true';
  const origin = args.origin || '';

  const backendBase = normalizeBaseUrl(args['backend-base'], '/saccapi', 'backend', allowLocalhost);
  const registryBase = normalizeBaseUrl(args['registry-base'], '/registryapi', 'registry', allowLocalhost);

  const errors = [
    ...(await checkEndpoint({
      url: backendBase,
      label: 'backend',
      expectedStatus: 200,
      expectedMarker: 'OK',
      origin,
    })),
    ...(await checkEndpoint({
      url: registryBase,
      label: 'registry',
      expectedStatus: 200,
      expectedMarker: 'OK',
      origin,
    })),
  ];

  if (errors.length > 0) {
    console.error('deployed-endpoints-check: FAIL');
    for (const error of errors) console.error(`- ${error}`);
    return 1;
  }

  console.log('deployed-endpoints-check: PASS');
  return 0;
}

if (require.main === module) {
  run().then((code) => process.exit(code)).catch((err) => {
    console.error('deployed-endpoints-check: FAIL');
    console.error(err.message);
    process.exit(1);
  });
}

module.exports = {
  normalizeBaseUrl,
  checkEndpoint,
  run,
};
