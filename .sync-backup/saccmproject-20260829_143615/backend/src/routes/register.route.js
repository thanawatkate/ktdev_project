const express = require('express');
const router = express.Router();
const c = require('../sacc_register/controllers/register.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

// off-budget ledger
router.get('/offbudget/categories', c.getOffBudgetCategories);
router.get('/offbudget/ledger', c.getOffBudgetLedger);

// generic registers
router.get('/evidence', c.getEvidenceRegister);
router.get('/voucher', c.getVoucherRegister);
router.get('/cheque', c.getChequeRegister);
router.get('/loan', c.getLoanRegister);
router.get('/current-account', c.getCurrentAccountRegister);
router.get('/agency-deposit', c.getAgencyDepositRegister);
router.get('/treasury-remit', c.getTreasuryRemitRegister);

// receipt book
router.get('/receipt-books', c.listReceiptBooks);
router.post('/receipt-books', c.createReceiptBook);
router.patch('/receipt-books/:id', c.updateReceiptBook);
router.delete('/receipt-books/:id', c.removeReceiptBook);
router.get('/receipt-books/:id/issues', c.listReceiptIssues);
router.post('/receipt-books/:id/issues', c.issueReceipt);

// deposit guarantee
router.get('/deposits/reconciliation', c.depositReconciliation);
router.get('/deposits/due-soon', c.listDepositsDueSoon);
router.get('/deposits', c.listDeposits);
router.get('/deposits/:id', c.getDeposit);
router.post('/deposits', c.createDeposit);
router.post('/deposits/receive-with-income', c.receiveDepositWithIncome);
router.patch('/deposits/:id', c.updateDeposit);
router.delete('/deposits/:id', c.removeDeposit);
router.post('/deposits/:id/settle', c.settleDeposit);
router.post('/deposits/:id/return-with-expense', c.returnDepositWithExpense);

module.exports = router;
