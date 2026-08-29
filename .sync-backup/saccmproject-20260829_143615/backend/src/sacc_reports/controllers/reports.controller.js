const service = require('../services/reports.service');
const extra = require('../services/extra_reports.service');

async function getSummary(req, res, next) {
  try { res.json(await service.getSummaryReport(req.query)); }
  catch (err) { next(err); }
}

async function getIncomeByMonth(req, res, next) {
  try { res.json(await service.getIncomeByMonth(req.query)); }
  catch (err) { next(err); }
}

async function getExpenseByMonth(req, res, next) {
  try { res.json(await service.getExpenseByMonth(req.query)); }
  catch (err) { next(err); }
}

async function getExpenseByBudgetSource(req, res, next) {
  try { res.json(await service.getExpenseByBudgetSource(req.query)); }
  catch (err) { next(err); }
}

async function getTrialBalance(req, res, next) {
  try { res.json(await service.getTrialBalance(req.query)); }
  catch (err) { next(err); }
}

async function getDailyTransactions(req, res, next) {
  try { res.json(await service.getDailyTransactions(req.query)); }
  catch (err) { next(err); }
}

async function getBudgetRemaining(req, res, next) {
  try { res.json(await service.getBudgetRemaining(req.query)); }
  catch (err) { next(err); }
}

async function getDailyBalance(req, res, next) {
  try { res.json(await extra.getDailyBalance(req.query)); }
  catch (err) { next(err); }
}

async function getBankReconciliation(req, res, next) {
  try { res.json(await extra.getBankReconciliation(req.query)); }
  catch (err) { next(err); }
}

async function getAnnualSummary(req, res, next) {
  try { res.json(await extra.getAnnualSummary(req.query)); }
  catch (err) { next(err); }
}

async function getDailyCashSummary(req, res, next) {
  try { res.json(await extra.getDailyCashSummary(req.query)); }
  catch (err) { next(err); }
}

async function getOutstandingCheques(req, res, next) {
  try { res.json(await extra.getOutstandingCheques(req.query)); }
  catch (err) { next(err); }
}

module.exports = {
  getSummary,
  getIncomeByMonth,
  getExpenseByMonth,
  getExpenseByBudgetSource,
  getTrialBalance,
  getDailyTransactions,
  getBudgetRemaining,
  getDailyBalance,
  getBankReconciliation,
  getAnnualSummary,
  getDailyCashSummary,
  getOutstandingCheques,
};
