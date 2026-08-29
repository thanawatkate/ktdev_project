const compression = require('compression');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');

function parseList(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function buildCorsOptions() {
  const allowedOrigins = parseList(process.env.CORS_ORIGIN || process.env.CORS_ORIGINS);
  const isProduction = process.env.NODE_ENV === 'production';

  return {
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (!isProduction && allowedOrigins.length === 0) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error('CORS origin not allowed'));
    },
    credentials: true,
  };
}

function applyHttpHardening(app) {
  app.disable('x-powered-by');
  if (process.env.TRUST_PROXY === 'true') {
    app.set('trust proxy', 1);
  }

  app.use(helmet({
    crossOriginResourcePolicy: false,
  }));
  app.use(cors(buildCorsOptions()));
  app.use(compression());
  app.use(rateLimit({
    windowMs: Number.parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 15 * 60 * 1000,
    limit: Number.parseInt(process.env.RATE_LIMIT_MAX, 10) || 600,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    skip: (req) => req.path === '/saccapi',
  }));
}

module.exports = {
  applyHttpHardening,
};
