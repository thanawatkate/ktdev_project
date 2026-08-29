const offbudgetSvc = require('../services/offbudget_register.service');
const genericSvc = require('../services/generic_register.service');
const receiptBookSvc = require('../services/receipt_book.service');
const depositSvc = require('../services/deposit_guarantee.service');

const meta = (req) => ({
  userId: req.body?.actor_id || null,
  userName: req.body?.actor_name || null,
  ip: req.ip || null,
});

async function safeRoute(handler) {
  return async (req, res, next) => {
    try { res.json(await handler(req, res)); }
    catch (err) { next(err); }
  };
}

module.exports = {
  // off-budget ledger
  getOffBudgetCategories: async (req, res, next) => {
    try { res.json(await offbudgetSvc.listOffBudgetCategories()); }
    catch (err) { next(err); }
  },
  getOffBudgetLedger: async (req, res, next) => {
    try { res.json(await offbudgetSvc.getOffBudgetLedger(req.query)); }
    catch (err) { next(err); }
  },

  // generic registers
  getEvidenceRegister: async (req, res, next) => {
    try { res.json(await genericSvc.getEvidenceRegister(req.query)); }
    catch (err) { next(err); }
  },
  getVoucherRegister: async (req, res, next) => {
    try { res.json(await genericSvc.getVoucherRegister(req.query)); }
    catch (err) { next(err); }
  },
  getChequeRegister: async (req, res, next) => {
    try { res.json(await genericSvc.getChequeRegister(req.query)); }
    catch (err) { next(err); }
  },
  getLoanRegister: async (req, res, next) => {
    try { res.json(await genericSvc.getLoanRegister(req.query)); }
    catch (err) { next(err); }
  },
  getCurrentAccountRegister: async (req, res, next) => {
    try { res.json(await genericSvc.getCurrentAccountRegister(req.query)); }
    catch (err) { next(err); }
  },
  getAgencyDepositRegister: async (req, res, next) => {
    try { res.json(await genericSvc.getAgencyDepositRegister(req.query)); }
    catch (err) { next(err); }
  },
  getTreasuryRemitRegister: async (req, res, next) => {
    try { res.json(await genericSvc.getTreasuryRemitRegister(req.query)); }
    catch (err) { next(err); }
  },

  // receipt book
  listReceiptBooks: async (req, res, next) => {
    try { res.json(await genericSvc.getReceiptBookRegister(req.query)); }
    catch (err) { next(err); }
  },
  createReceiptBook: async (req, res, next) => {
    try { res.json(await receiptBookSvc.createBook(req.body, meta(req))); }
    catch (err) { next(err); }
  },
  updateReceiptBook: async (req, res, next) => {
    try { res.json(await receiptBookSvc.updateBook(req.params.id, req.body, meta(req))); }
    catch (err) { next(err); }
  },
  removeReceiptBook: async (req, res, next) => {
    try { res.json(await receiptBookSvc.removeBook(req.params.id, req.body, meta(req))); }
    catch (err) { next(err); }
  },
  listReceiptIssues: async (req, res, next) => {
    try { res.json(await genericSvc.listReceiptIssues(req.params.id)); }
    catch (err) { next(err); }
  },
  issueReceipt: async (req, res, next) => {
    try { res.json(await receiptBookSvc.issueReceipt(req.params.id, req.body, meta(req))); }
    catch (err) { next(err); }
  },

  // deposit guarantee
  listDeposits: async (req, res, next) => {
    try { res.json(await depositSvc.list(req.query.page, req.query)); }
    catch (err) { next(err); }
  },
  getDeposit: async (req, res, next) => {
    try { res.json(await depositSvc.getById(req.params.id)); }
    catch (err) { next(err); }
  },
  createDeposit: async (req, res, next) => {
    try { res.json(await depositSvc.create(req.body, meta(req))); }
    catch (err) { next(err); }
  },
  receiveDepositWithIncome: async (req, res, next) => {
    try { res.json(await depositSvc.receiveWithIncome(req.body, meta(req))); }
    catch (err) { next(err); }
  },
  returnDepositWithExpense: async (req, res, next) => {
    try { res.json(await depositSvc.returnWithExpense(req.params.id, req.body, meta(req))); }
    catch (err) { next(err); }
  },
  depositReconciliation: async (req, res, next) => {
    try { res.json(await depositSvc.reconciliation(req.query)); }
    catch (err) { next(err); }
  },
  listDepositsDueSoon: async (req, res, next) => {
    try { res.json(await depositSvc.listDueSoon(req.query)); }
    catch (err) { next(err); }
  },
  updateDeposit: async (req, res, next) => {
    try { res.json(await depositSvc.update(req.params.id, req.body, meta(req))); }
    catch (err) { next(err); }
  },
  removeDeposit: async (req, res, next) => {
    try { res.json(await depositSvc.remove(req.params.id, req.body, meta(req))); }
    catch (err) { next(err); }
  },
  settleDeposit: async (req, res, next) => {
    try { res.json(await depositSvc.settle(req.params.id, req.body, meta(req))); }
    catch (err) { next(err); }
  },
};
