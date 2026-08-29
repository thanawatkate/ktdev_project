const express = require('express');
const router = express.Router();
const controller = require('../sacc_docgroup/controllers/saccdocgroup.controller');
const { requireAuth } = require('../middleware/auth.middleware');

/* GET programming languages. */
router.get('/', controller.get);

/* POST user   */
router.post('/', requireAuth, controller.create);

router.get('/createdocno/', requireAuth, controller.createdocno);
/* PUT  */
router.patch('/:id', requireAuth, controller.update);

/* DELETE  */
router.delete('/:id', requireAuth, controller.remove);



module.exports = router;
