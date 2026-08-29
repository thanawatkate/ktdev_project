const service = require('../services/expensesub.service');

async function get(req, res, next) {
  try {
    res.json(await service.getMultiple(req.query.page));
  } catch (err) {
    console.error(`Error while getting  `, err.message);
    next(err);
  }
}

async function create(req, res, next) {
  try {
    res.json(await service.create(req.body));
  } catch (err) {
    console.error(`Error while creating  `, err.message);
    next(err);
  }
}
async function createInExpenseSub(refexpense, data) {

  return await service.createInExpenseSub(refexpense, data);

}
async function update(req, res, next) {
  try {
    res.json(await service.update(req.params.id, req.body));
  } catch (err) {
    console.error(`Error while updating   `, err.message);
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    res.json(await service.remove(req.params.id, req.body));
  } catch (err) {
    console.error(`Error while deleting  `, err.message);
    next(err);
  }
}

module.exports = {
  get,
  create,
  update,
  remove,
  createInExpenseSub
};
