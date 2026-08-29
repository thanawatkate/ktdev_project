const express = require('express');
const router = express.Router();
const controller = require('../sacc_finance_compliance/controllers/finance_compliance.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

router.get('/alerts', controller.getAlerts);
router.post('/close-day', controller.postCloseDay);
router.get('/daily-closings', controller.getClosings);
router.get('/daily-closing', controller.getClosing);
router.post('/reconciliation-note', controller.postReconciliationNote);
router.get('/reconciliation-notes', controller.getReconciliationNotes);

module.exports = router;
