const express = require('express');
const router = express.Router();
const controller = require('../sacc_fiscal_year_opening/controllers/fiscal_year_opening.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

// GET /api/fiscal-year-opening?fiscal_year=2569
router.get('/', controller.listGrid);

// GET /api/fiscal-year-opening/suggested?fiscal_year=2569
router.get('/suggested', controller.getSuggested);

// POST /api/fiscal-year-opening  body: { token, fiscal_year, rows: [{bucket, pocket, opening_amount, remark?}] }
router.post('/', controller.upsertGrid);

// POST /api/fiscal-year-opening/copy-from-previous body: { token, fiscal_year }
router.post('/copy-from-previous', controller.copyFromPrev);

module.exports = router;
