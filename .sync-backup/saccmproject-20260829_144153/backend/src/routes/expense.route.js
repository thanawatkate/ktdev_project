const express = require('express');
const router = express.Router();
const controller = require('../sacc_expense/controllers/expense.controller');
const subController = require('../sacc_expensesub/controllers/expensesub.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

/* GET programming languages. */
router.get('/', controller.get);

/* POST user   */
router.post('/', controller.create);

/* PUT programming language */
router.patch('/:id', controller.update);

/* DELETE programming language */
router.delete('/:id', controller.remove);


// get sub 
router.get('/sub/', subController.get);

// Delete sub data
router.delete('/sub/:id', subController.remove);

module.exports = router;
