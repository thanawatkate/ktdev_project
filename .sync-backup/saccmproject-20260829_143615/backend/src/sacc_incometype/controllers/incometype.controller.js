const service = require('../services/incometype.service');

async function get(req, res, next) {
  try {
    res.json(await service.getMultiple(req.query.page));
  } catch (err) {
    console.error(`Error while getting`, err.message);
    next(err);
  }
}

async function create(req, res, next) {
  try {
    res.json(await service.create(req.body));
  } catch (err) {
    console.error(`Error while creating`, err.message);
    next(err);
  }
}

async function update(req, res, next) {
  try {
    res.json(await service.update(req.params.id, req.body));
  } catch (err) {
    console.error(`Error while updating`, err.message);
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    res.json(await service.remove(req.params.id, req.body));
  } catch (err) {
    console.error(`Error while deleting`, err.message);
    next(err);
  }
}

async function getLinkedBudgetSources(req, res, next) {
  try {
    res.json(await service.getLinkedBudgetSources(req.params.id));
  } catch (err) {
    console.error(`Error while getting linked budget sources`, err.message);
    next(err);
  }
}

async function replaceLinkedBudgetSources(req, res, next) {
  try {
    res.json(await service.replaceLinkedBudgetSources(req.params.id, req.body));
  } catch (err) {
    console.error(`Error while updating linked budget sources`, err.message);
    next(err);
  }
}

module.exports = {
  get,
  create,
  update,
  remove,
  getLinkedBudgetSources,
  replaceLinkedBudgetSources,
};
