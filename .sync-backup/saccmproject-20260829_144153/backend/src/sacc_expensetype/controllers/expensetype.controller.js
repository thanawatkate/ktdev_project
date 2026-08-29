const service = require('../services/expensetype.service');

async function get(req, res, next) {
  try {
    res.json(await service.getMultiple(req.query.page));
  } catch (err) {
    console.error('Error while getting expensetype', err.message);
    next(err);
  }
}

async function create(req, res, next) {
  try {
    res.json(await service.create(req.body));
  } catch (err) {
    console.error('Error while creating expensetype', err.message);
    next(err);
  }
}

async function update(req, res, next) {
  try {
    res.json(await service.update(req.params.id, req.body));
  } catch (err) {
    console.error('Error while updating expensetype', err.message);
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    res.json(await service.remove(req.params.id, req.body));
  } catch (err) {
    console.error('Error while deleting expensetype', err.message);
    next(err);
  }
}

module.exports = {
  get,
  create,
  update,
  remove,
};
