const express = require('express');
const router = express.Router();
const controller = require('../sacc_reports/controllers/reports.controller');
const auditController = require('../sacc_auditlog/auditlog.service');
const { requireReportAccess } = require('../middleware/report-auth.middleware');

router.use(requireReportAccess);

// ── รายงานหลัก ────────────────────────────────────────────────────────────────

// สรุปภาพรวม รายรับ-รายจ่าย (?date_from=&date_to=)
router.get('/summary', controller.getSummary);

// รายรับแยกตามเดือน (?fiscal_year=2568)
router.get('/income-by-month', controller.getIncomeByMonth);

// รายจ่ายแยกตามเดือน (?fiscal_year=2568)
router.get('/expense-by-month', controller.getExpenseByMonth);

// รายงานแยกตามแหล่งเงิน (?fiscal_year=2568)
router.get('/by-budget-source', controller.getExpenseByBudgetSource);

// งบทดลอง (?date_from=&date_to=)
router.get('/trial-balance', controller.getTrialBalance);

// รายวัน (?date=2026-04-30)
router.get('/daily', controller.getDailyTransactions);

// งบประมาณคงเหลือ (?fiscal_year=2568)
router.get('/budget-remaining', controller.getBudgetRemaining);

// รายงานเงินคงเหลือประจำวัน (?date=YYYY-MM-DD) — คู่มือหน้า 34
router.get('/daily-balance', controller.getDailyBalance);

// สรุปเงินสดรายวัน (?date=YYYY-MM-DD) — ยอดยกมา / รับสด / รับโอน / จ่ายสด / ยกไป
router.get('/daily-cash-summary', controller.getDailyCashSummary);

// งบเทียบยอดเงินฝากธนาคาร (?date=YYYY-MM-DD) — คู่มือหน้า 32
router.get('/bank-reconciliation', controller.getBankReconciliation);

// รายงานรับ-จ่ายเงินรายได้สถานศึกษา ประจำปีงบประมาณ (?fiscal_year=2568) — คู่มือหน้า 33
router.get('/annual-summary', controller.getAnnualSummary);

// เช็คค้างตัดบัญชี (?date=YYYY-MM-DD&fiscal_year=2568)
router.get('/outstanding-cheques', controller.getOutstandingCheques);

// ── Audit Log ──────────────────────────────────────────────────────────────────
router.get('/audit-log', async (req, res, next) => {
  try { res.json(await auditController.getLogs(req.query)); }
  catch (err) { next(err); }
});

module.exports = router;
