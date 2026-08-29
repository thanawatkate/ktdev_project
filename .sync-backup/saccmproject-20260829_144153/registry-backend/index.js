require('dotenv').config();
const express = require('express');
const ensureDatabaseExists = require('./src/utils/ensure-database');
const db = require('./src/utils/db');
const licenseRoutes = require('./src/routes/license.route');
const trialRoutes = require('./src/routes/trial.route');
const { applyHttpHardening } = require('./src/utils/security.middleware');
const { validateRegistryRuntimeConfig } = require('./src/utils/runtime-config.validate');

validateRegistryRuntimeConfig();

const app = express();
const port = process.env.PORT || 3802;

applyHttpHardening(app);
app.use(express.json({ limit: process.env.REQUEST_BODY_LIMIT || '512kb' }));
app.use(express.urlencoded({
  extended: false,
  limit: process.env.REQUEST_BODY_LIMIT || '512kb',
}));

app.get('/registryapi', (req, res) => {
  res.json({
    service: 'SACCM Registry',
    status: 'OK',
    note: 'ทดลองใช้ 90 วัน — anchor วันเริ่มไว้ที่ /registryapi/trial/start',
    timestamp: new Date().toISOString(),
  });
});

app.use('/registryapi/license', licenseRoutes);
app.use('/registryapi/trial', trialRoutes);

app.use((err, req, res, next) => {
  console.error('Registry error:', err.message);
  const isProduction = process.env.NODE_ENV === 'production';
  res.status(500).json({
    status: 'error',
    message: isProduction ? 'Internal server error' : err.message,
  });
});

async function start() {
  await ensureDatabaseExists();
  await db.migrate.latest();
  console.log('✅ Registry DB migrations OK');

  app.listen(port, '0.0.0.0', () => {
    console.log(`📋 SACCM Registry http://localhost:${port}/registryapi`);
  });
}

start().catch((err) => {
  console.error('❌ Registry start failed:', err.message);
  process.exit(1);
});
