const service = require('../services/budgetsource.service');

const _meta = (req) => ({
  userId: req.user?.id || null,
  userName: req.user?.name || null,
  ip: req.ip || req.connection?.remoteAddress || null,
});

async function getAll(req, res, next) {
  try { res.json(await service.getAll(req.query)); }
  catch (err) { next(err); }
}

async function getById(req, res, next) {
  try { res.json(await service.getById(req.params.id)); }
  catch (err) { next(err); }
}

async function create(req, res, next) {
  try { res.json(await service.create(req.body, _meta(req))); }
  catch (err) { next(err); }
}

async function update(req, res, next) {
  try { res.json(await service.update(req.params.id, req.body, _meta(req))); }
  catch (err) { next(err); }
}

async function remove(req, res, next) {
  try { res.json(await service.remove(req.params.id, req.body, _meta(req))); }
  catch (err) { next(err); }
}

module.exports = { getAll, getById, create, update, remove };
