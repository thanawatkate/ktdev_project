// คืนเงินยืม
const express = require('express');
const router = express.Router();
const controller = require('../sacc_repayloan/controllers/repayloan.controller');
const subController = require('../sacc_repayloansub/controllers/repayloansub.controller');
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


// subloan 
router.get('/sub/', subController.get);

// Delete sub data
router.delete('/sub/:id', subController.remove);

module.exports = router;

