const express = require('express');
const router = express.Router();
const userController = require('../sacc_users/controllers/users.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

/* GET programming languages. */
router.get('/', userController.get);

/* POST user   */
router.post('/', userController.create);

/* PUT programming language */
router.patch('/:id', userController.update);

/* DELETE programming language */
router.delete('/:id', userController.remove);

module.exports = router;
