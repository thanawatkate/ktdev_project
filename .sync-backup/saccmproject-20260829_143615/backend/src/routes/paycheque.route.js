const express = require('express');
const router = express.Router();
const controller = require('../sacc_paycheque/controllers/paycheque.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

router.get('/', controller.get);

router.post('/', controller.create);
router.patch('/:id', controller.update);
router.delete('/:id', controller.remove);

module.exports = router;
