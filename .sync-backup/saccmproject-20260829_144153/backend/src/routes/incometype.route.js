const express = require('express');
const router = express.Router();
const controller = require('../sacc_incometype/controllers/incometype.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

/* GET programming languages. */
router.get('/', controller.get);

/* POST user   */
router.post('/', controller.create);

/* PUT programming language */
router.patch('/:id', controller.update);

/* GET linked budget sources for income type */
router.get('/:id/budgetsources', controller.getLinkedBudgetSources);

/* PUT replace linked budget sources for income type */
router.put('/:id/budgetsources', controller.replaceLinkedBudgetSources);

/* DELETE programming language */
router.delete('/:id', controller.remove);

module.exports = router;
