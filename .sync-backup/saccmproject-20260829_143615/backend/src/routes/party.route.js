const express = require('express');
const router = express.Router();
const controller = require('../sacc_party/controllers/party.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

router.get('/', controller.get);
router.get('/audit-log', controller.getAudit);
router.get('/:id/audit-log', controller.getAudit);
router.post('/', controller.create);
router.patch('/:id', controller.update);
router.delete('/:id', controller.remove);

module.exports = router;
