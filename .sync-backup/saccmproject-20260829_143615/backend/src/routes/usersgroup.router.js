const express = require('express');
const router = express.Router();
const userController = require('../sacc_usergroup/controllers/usergroup.controller');
const { requireAuth } = require('../middleware/auth.middleware');

/* GET programming languages. */
router.get('/', userController.get);

/* POST user   */
router.post('/', requireAuth, userController.create);

/* PUT programming language */
router.patch('/:id', requireAuth, userController.update);

/* DELETE programming language */
router.delete('/:id', requireAuth, userController.remove);

module.exports = router;
