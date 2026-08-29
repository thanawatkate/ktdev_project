const express = require('express');
const router = express.Router();
const controller = require('../sacc_expensereq/controllers/expensereq.controller');
const subController = require('../sacc_expensereqsub/controllers/expensereqsub.controller');
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


// sub 
router.get('/sub/', subController.get);

// Delete sub  
router.delete('/sub/:id', subController.remove);


module.exports = router;
