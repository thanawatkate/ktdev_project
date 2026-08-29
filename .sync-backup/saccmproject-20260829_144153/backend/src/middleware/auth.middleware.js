const {
  checkTokenEXP,
  decodeTokenPayloadSync,
} = require('../sacc_login/services/login.service');

function extractToken(req) {
  const auth = req.headers.authorization;
  if (auth && auth.startsWith('Bearer ')) return auth.slice(7);
  if (req.body?.token) return req.body.token;
  if (req.query?.token) return req.query.token;
  return null;
}

function requireAuth(req, res, next) {
  try {
    const token = extractToken(req);
    if (!token || checkTokenEXP(token)) {
      return res.status(401).json({
        success: false,
        status: 'error',
        message: 'Token หมดอายุหรือไม่ถูกต้อง',
      });
    }

    req.auth = decodeTokenPayloadSync(token);
    req.token = token;
    return next();
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  extractToken,
  requireAuth,
};
