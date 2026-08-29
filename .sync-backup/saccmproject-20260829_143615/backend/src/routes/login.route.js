const express = require('express');
const router = express.Router();
const Controller = require('../sacc_login/controllers/login.controller');

/* GET token . */
router.get('/token', Controller.checkToken);
/* GET token . */
router.get('/token/exp', Controller.checkTokenEXP);
/* POST programming language */
router.post('/token', Controller.createToken);

/* PUT programming language */
// router.put('/:id', userController.update);

/* DELETE programming language */
// router.delete('/:id', userController.remove);

module.exports = router;
