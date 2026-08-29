const express = require('express');
const router = express.Router();
const programmingLanguagesController = require('../programmingLanguages/controllers/programmingLanguages.controller');

/* GET programming languages. */
router.get('/', programmingLanguagesController.get);

/* POST programming language */
router.post('/', programmingLanguagesController.create);

/* PUT programming language */
router.patch('/:id', programmingLanguagesController.update);

/* DELETE programming language */
router.delete('/:id', programmingLanguagesController.remove);

module.exports = router;
