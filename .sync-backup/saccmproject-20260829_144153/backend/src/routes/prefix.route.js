const express = require('express');
const router = express.Router();
const controller = require('../sacc_prefix/controllers/prefix.controller');
const { requireAuth } = require('../middleware/auth.middleware');

/* GET   */
router.get('/', controller.get);

/* POST   */
router.post('/', requireAuth, controller.create);

/* PUT  */
router.patch('/:id', requireAuth, controller.update);

/* DELETE  */
router.delete('/:id', requireAuth, controller.remove);


module.exports = router;
