const trial = require('../services/trial.service');

function clientIp(req) {
  return req.headers['x-forwarded-for']?.split(',')[0]?.trim()
    || req.socket?.remoteAddress
    || null;
}

async function start(req, res, next) {
  try {
    const result = await trial.startTrial(req.body, clientIp(req));
    res.status(result.status === 'success' ? 200 : 400).json(result);
  } catch (err) {
    next(err);
  }
}

module.exports = { start };
