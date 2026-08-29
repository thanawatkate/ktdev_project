const service = require('../services/party.service');
const { getLogs } = require('../../sacc_auditlog/auditlog.service');

async function get(req, res, next) {
  try {
    res.json(await service.getMultiple(req.query.page, req.query));
  } catch (err) {
    console.error('Error while getting party list', err.message);
    next(err);
  }
}

async function create(req, res, next) {
  try {
    res.json(await service.create(req.body, {
      userId: req.body?.actor_id || null,
      userName: req.body?.actor_name || null,
      ip: req.ip || null,
    }));
  } catch (err) {
    console.error('Error while creating party', err.message);
    next(err);
  }
}

async function update(req, res, next) {
  try {
    res.json(await service.update(req.params.id, req.body, {
      userId: req.body?.actor_id || null,
      userName: req.body?.actor_name || null,
      ip: req.ip || null,
    }));
  } catch (err) {
    console.error('Error while updating party', err.message);
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    res.json(await service.remove(req.params.id, req.body, {
      userId: req.body?.actor_id || null,
      userName: req.body?.actor_name || null,
      ip: req.ip || null,
    }));
  } catch (err) {
    console.error('Error while deleting party', err.message);
    next(err);
  }
}

async function getAudit(req, res, next) {
  try {
    const query = { ...req.query, tablename: 'party' };
    if (req.params.id) {
      query.record_id = req.params.id;
    }
    res.json(await getLogs(query));
  } catch (err) {
    console.error('Error while getting party audit logs', err.message);
    next(err);
  }
}

module.exports = {
  get,
  create,
  update,
  remove,
  getAudit,
};
