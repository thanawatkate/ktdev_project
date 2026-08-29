const express = require('express');
const router = express.Router();
const controller = require('../sacc_member/controllers/member.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

/* GET  */
router.get('/', controller.get);

/* POST     */
router.post('/', controller.create);

/* PUT   */
router.patch('/:id', controller.update);

/* DELETE  */
router.delete('/:id', controller.remove);

module.exports = router;
