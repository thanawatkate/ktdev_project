const express = require('express');
const router = express.Router();
const controller = require('../sacc_income/controllers/income.controller');
const subController = require('../sacc_incomesub/controllers/incomesub.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

/* GET   */
router.get('/', controller.get);

/* POST    */
router.post('/', controller.create);

/* PUT  */
router.patch('/:id', controller.update);

/* DELETE  */
router.delete('/:id', controller.remove);

// sub 
router.get('/sub/', subController.get);

// Delete sub  
router.delete('/sub/:id', subController.remove);


module.exports = router;
