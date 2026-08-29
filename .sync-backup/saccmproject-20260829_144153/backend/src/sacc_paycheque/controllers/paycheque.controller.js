const service = require('../services/paycheque.service');

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
    res.json(await service.create(req.body?.token, req.body || {}));
  } catch (err) {
    console.error(`Error while creating  `, err.message);
    next(err);
  }
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
async function createInPayCheque(token, refexpense, data, trx) {
  return await service.createPayCheque(token, refexpense, data, trx);
}
module.exports = {
  get,
  create,
  update,
  remove,
  createInPayCheque
};
