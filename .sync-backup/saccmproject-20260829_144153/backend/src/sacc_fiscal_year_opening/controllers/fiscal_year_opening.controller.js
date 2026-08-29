const service = require('../services/fiscal_year_opening.service');

const meta = (req) => ({
  userId: req.user?.id || req.body?.actor_id || null,
  userName: req.user?.name || req.body?.actor_name || null,
  ip: req.ip || req.connection?.remoteAddress || null,
});

async function listGrid(req, res, next) {
  try { res.json(await service.listGrid(req.query)); }
  catch (err) { next(err); }
}

async function upsertGrid(req, res, next) {
  try { res.json(await service.upsertGrid(req.body, meta(req))); }
  catch (err) { next(err); }
}

async function getSuggested(req, res, next) {
  try { res.json(await service.computeSuggestedOpening(req.query)); }
  catch (err) { next(err); }
}

async function copyFromPrev(req, res, next) {
  try { res.json(await service.copyFromPreviousYearEnding(req.body, meta(req))); }
  catch (err) { next(err); }
}

module.exports = {
  listGrid,
  upsertGrid,
  getSuggested,
  copyFromPrev,
};
