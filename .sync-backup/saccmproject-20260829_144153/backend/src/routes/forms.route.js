const express = require('express');
const router = express.Router();
const c = require('../sacc_forms/controllers/forms.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

// PDF endpoints — รับ body JSON แล้วคืน PDF stream
router.post('/receipt-substitute', c.postReceiptSubstitute);
router.post('/voucher-receive', c.postVoucherReceive);
router.post('/withholding-tax', c.postWithholdingTax);
router.post('/receipt-attachment', c.postReceiptAttachment);
router.post('/deposit-register', c.postDepositRegister);
router.post('/loan-contract', c.postLoanContract);

module.exports = router;
