const express = require('express');
const router = express.Router();
const controller = require('../sacc_moneytype/controllers/moneytype.controller');
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

module.exports = router;
