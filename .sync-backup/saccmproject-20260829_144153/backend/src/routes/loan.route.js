//บันทึกเงินยืม
const express = require('express');
const router = express.Router();
const controller = require('../sacc_loan/controllers/loan.controller');
const loanSubController = require('../sacc_loansub/controllers/loansub.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

/* GET   */
router.get('/', controller.get);

/* POST   */
router.post('/', controller.create);

/* PUT  */
router.patch('/:id', controller.update);

/* DELETE  */
router.delete('/:id', controller.remove);


// รายละเอียดย่อยเงินยืม (loansub) — เดิมชี้ผิดไป repayloan
router.get('/sub/', loanSubController.get);
router.delete('/sub/:id', loanSubController.remove);

module.exports = router;
