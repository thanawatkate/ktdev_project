const svc = require('../services/finance_compliance.service');

async function getAlerts(req, res, next) {
  try {
    res.json(await svc.getComplianceAlerts(req.query));
  } catch (err) {
    next(err);
  }
}

async function postCloseDay(req, res, next) {
  try {
    const out = await svc.closeDay(req.body);
    res.status(out.status === 'error' ? 400 : 200).json(out);
  } catch (err) {
    next(err);
  }
}

async function getClosings(req, res, next) {
  try {
    res.json(await svc.listDailyClosings(req.query));
  } catch (err) {
    next(err);
  }
}

async function getClosing(req, res, next) {
  try {
    res.json(await svc.getDailyClosing(req.query));
  } catch (err) {
    next(err);
  }
}

async function postReconciliationNote(req, res, next) {
  try {
    const out = await svc.saveReconciliationAdjustment(req.body);
    res.status(out.status === 'error' ? 400 : 200).json(out);
  } catch (err) {
    next(err);
  }
}

async function getReconciliationNotes(req, res, next) {
  try {
    res.json(await svc.listReconciliationAdjustments(req.query));
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getAlerts,
  postCloseDay,
  getClosings,
  getClosing,
  postReconciliationNote,
  getReconciliationNotes,
};
