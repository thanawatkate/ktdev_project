const license = require('../services/license.service');

function clientIp(req) {
  return req.headers['x-forwarded-for']?.split(',')[0]?.trim()
    || req.socket?.remoteAddress
    || null;
}

function checkAdmin(req, res) {
  const secret = process.env.LICENSE_ADMIN_SECRET;
  if (!secret || req.headers['x-license-admin-secret'] !== secret) {
    res.status(401).json({ status: 'error', message: 'ไม่มีสิทธิ์' });
    return false;
  }
  return true;
}

async function activate(req, res, next) {
  try {
    const result = await license.activateLicense(req.body, clientIp(req));
    res.status(result.status === 'success' ? 200 : 400).json(result);
  } catch (err) {
    next(err);
  }
}

async function validate(req, res, next) {
  try {
    res.json(await license.validateLicense(req.body));
  } catch (err) {
    next(err);
  }
}

async function heartbeat(req, res, next) {
  try {
    res.json(await license.heartbeat(req.body, clientIp(req)));
  } catch (err) {
    next(err);
  }
}

async function token(req, res, next) {
  try {
    const result = await license.issueServerToken(req.body);
    res.status(result.status === 'success' ? 200 : 400).json(result);
  } catch (err) {
    next(err);
  }
}

async function generate(req, res, next) {
  try {
    if (!checkAdmin(req, res)) return;
    const result = await license.generateLicense(req.body);
    res.status(result.status === 'success' ? 201 : 400).json(result);
  } catch (err) {
    next(err);
  }
}

async function list(req, res, next) {
  try {
    if (!checkAdmin(req, res)) return;
    res.json(await license.listLicenses());
  } catch (err) {
    next(err);
  }
}

async function issueLogs(req, res, next) {
  try {
    if (!checkAdmin(req, res)) return;
    const limit = parseInt(req.query.limit, 10) || 100;
    res.json(await license.listIssueLogs(limit));
  } catch (err) {
    next(err);
  }
}

async function activationLogs(req, res, next) {
  try {
    if (!checkAdmin(req, res)) return;
    const limit = parseInt(req.query.limit, 10) || 100;
    res.json(await license.listActivationLogs({
      schoolCode: req.query.schoolCode,
      limit,
    }));
  } catch (err) {
    next(err);
  }
}

async function revoke(req, res, next) {
  try {
    if (!checkAdmin(req, res)) return;
    const result = await license.revokeLicense(req.body);
    res.status(result.status === 'success' ? 200 : 400).json(result);
  } catch (err) {
    next(err);
  }
}

async function status(req, res, next) {
  try {
    const result = await license.getSchoolLicenseStatus(req.body);
    res.status(result.status === 'success' ? 200 : 400).json(result);
  } catch (err) {
    next(err);
  }
}

module.exports = {
  activate,
  validate,
  heartbeat,
  token,
  generate,
  list,
  issueLogs,
  activationLogs,
  revoke,
  status,
};
