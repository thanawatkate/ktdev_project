const express = require('express');
const Controller = require('../controllers/license.controller');

const router = express.Router();

router.post('/activate', Controller.activate);
router.post('/validate', Controller.validate);
router.post('/token', Controller.token);
router.post('/status', Controller.status);
router.post('/heartbeat', Controller.heartbeat);

router.post('/admin/generate', Controller.generate);
router.get('/admin/list', Controller.list);
router.get('/admin/issue-logs', Controller.issueLogs);
router.get('/admin/activation-logs', Controller.activationLogs);
router.post('/admin/revoke', Controller.revoke);

module.exports = router;
