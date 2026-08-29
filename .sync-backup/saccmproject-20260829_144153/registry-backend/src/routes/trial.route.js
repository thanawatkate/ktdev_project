const express = require('express');
const Controller = require('../controllers/trial.controller');

const router = express.Router();

router.post('/start', Controller.start);

module.exports = router;
