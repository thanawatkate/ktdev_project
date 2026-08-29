
// Core dependencies
require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const initDatabase = require('./src/utils/db.init');
const { applyHttpHardening } = require('./src/middleware/security.middleware');
const { validateBackendRuntimeConfig } = require('./src/utils/runtime-config.validate');

validateBackendRuntimeConfig();

// Initialize Express app
const app = express();
const port = process.env.PORT || 3800;

// Track database readiness — false until initDatabase() succeeds
let dbReady = false;

// Import route modules
// Authentication & User Management
const login = require('./src/routes/login.route');
const users = require('./src/routes/users.route');
const usersgroup = require('./src/routes/usersgroup.router');

// Master Data Routes
const prefix = require('./src/routes/prefix.route');
const docgroup = require('./src/routes/docgroup.route');
const member = require('./src/routes/member.route');

// Money & Banking Routes
const moneytype = require('./src/routes/moneytype.route');
const moneygroup = require('./src/routes/moneygroup.route');
const saccbank = require('./src/routes/bank.route');
const bankaccount = require('./src/routes/bankaccount.route');
const saccchequeaccount = require('./src/routes/chequeaccount.route');
const paycheque = require('./src/routes/paycheque.route');

// Financial Transaction Routes
const incometype = require('./src/routes/incometype.route');
const expensetype = require('./src/routes/expensetype.route');
const income = require('./src/routes/income.route');
const expense = require('./src/routes/expense.route');
const expensereq = require('./src/routes/expensereq.route');
const loan = require('./src/routes/loan.route');
const repayloan = require('./src/routes/repayloan.route');
const setup = require('./src/routes/setup.route');

// New: Government school compliance modules
const budgetsource = require('./src/routes/budget_source.route');
const approval = require('./src/routes/approval.route');
const reports = require('./src/routes/reports.route');
const party = require('./src/routes/party.route');
const menu = require('./src/routes/menu.route');
const syncDigest = require('./src/routes/sync_digest.route');
const registerRoutes = require('./src/routes/register.route');
const formsRoutes = require('./src/routes/forms.route');
const fiscalYearOpeningRoutes = require('./src/routes/fiscal_year_opening.route');
const financeComplianceRoutes = require('./src/routes/finance_compliance.route');
const internalRoutes = require('./src/routes/internal.route');
const { schoolContextMiddleware } = require('./src/middleware/school-context.middleware');
// Middleware configuration
applyHttpHardening(app);
app.use(bodyParser.json({ limit: process.env.REQUEST_BODY_LIMIT || '1mb' }));
app.use(bodyParser.urlencoded({
  extended: false,
  limit: process.env.REQUEST_BODY_LIMIT || '2mb',
}));

// Block non-setup routes when database is not ready
app.use((req, res, next) => {
  if (
    !dbReady &&
    !req.originalUrl.startsWith('/saccapi/setup') &&
    req.originalUrl !== '/saccapi'
  ) {
    return res.status(503).json({
      success: false,
      setupRequired: true,
      message: 'ฐานข้อมูลยังไม่พร้อม — กรุณาเปิดแอปแล้วกด "ตั้งค่าฐานข้อมูล" เพื่อตั้งค่าการเชื่อมต่อ',
    });
  }
  next();
});

// สลับ DB ต่อโรงเรียนจาก JWT / schoolCode
app.use(schoolContextMiddleware);

// Health check endpoint
app.get('/saccapi', (req, res) => {
  res.json({ 
    message: 'SACC API is running',
    status: 'OK',
    timestamp: new Date().toISOString()
  });
});

// API Routes
// Authentication & User Management
app.use('/saccapi/login', login);
app.use('/saccapi/users', users);
app.use('/saccapi/usersgroup', usersgroup);

// Master Data
app.use('/saccapi/prefix', prefix);
app.use('/saccapi/docgroup', docgroup);
app.use('/saccapi/member', member);

// Money & Banking
app.use('/saccapi/moneytype', moneytype);
app.use('/saccapi/moneygroup', moneygroup);
app.use('/saccapi/bank', saccbank);
app.use('/saccapi/bankaccount', bankaccount);
app.use('/saccapi/chequeaccount', saccchequeaccount);
app.use('/saccapi/paycheque', paycheque);

// Financial Transactions
app.use('/saccapi/incometype', incometype);
app.use('/saccapi/expensetype', expensetype);
app.use('/saccapi/income', income); // รับเข้า
app.use('/saccapi/expense', expense); // เบิกเงิน
app.use('/saccapi/expensereq', expensereq); // ขอเบิก
app.use('/saccapi/loan', loan);
app.use('/saccapi/repayloan', repayloan);
app.use('/saccapi/setup', setup);
app.use('/saccapi/internal', internalRoutes);

// Government school compliance modules
app.use('/saccapi/budgetsource', budgetsource);  // แหล่งเงิน/งบประมาณ
app.use('/saccapi/approval', approval);           // Workflow อนุมัติ
app.use('/saccapi/reports', reports);             // รายงานการเงิน
app.use('/saccapi/party', party);                 // ผู้จ่าย/ผู้รับ
app.use('/saccapi/menu', menu);                   // app_menu (เมนูแอป)
app.use('/saccapi/sync', syncDigest);             // digest สำหรับเทียบ local vs serverdb
app.use('/saccapi/register', registerRoutes);     // ทะเบียนคุม (เงินนอกงบฯ, ใบเสร็จ, เงินประกันสัญญา ฯลฯ)
app.use('/saccapi/forms', formsRoutes);           // PDF generator สำหรับเอกสารแนบ
app.use('/saccapi/fiscal-year-opening', fiscalYearOpeningRoutes); // ยอดยกมาต้นปีงบประมาณ (Daily balance หน้า 34)
app.use('/saccapi/finance-compliance', financeComplianceRoutes); // ปิดวัน / แจ้งเตือน / บันทึกเหตุผลเทียบยอดธนาคาร
// 404 handler for unknown routes
app.use('*', (req, res) => {
  res.status(404).json({ 
    message: 'Route not found',
    path: req.originalUrl,
    method: req.method
  });
});

/* Error handler middleware */
app.use((err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  console.error('Error:', err.message);
  const isProduction = process.env.NODE_ENV === 'production';
  
  res.status(statusCode).json({ 
    message: isProduction && statusCode >= 500 ? 'Internal server error' : err.message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// Start server — always start even if DB is not ready so setup routes are reachable
initDatabase().then((ready) => {
  dbReady = ready;
  app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 SACC API Server running on http://localhost:${port}`);
    console.log(`📊 Health check available at http://localhost:${port}/saccapi`);
    if (!ready) {
      console.log(`⚠️  Mode: SETUP — DB ไม่พร้อม เปิดแอปแล้วกด "ตั้งค่าฐานข้อมูล"`);
    }
  });
});
