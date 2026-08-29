const service = require('../services/approval.service');
const { decodeTokenPayloadSync } = require('../../sacc_login/services/login.service');

const _meta = (req) => ({
  userId: decodeTokenPayloadSync(req.body?.token || '')?.id || null,
  userName: (() => {
    const payload = decodeTokenPayloadSync(req.body?.token || '');
    if (!payload) return null;
    const first = payload.name || '';
    const last = payload.lastname || '';
    return `${first} ${last}`.trim() || payload.username || null;
  })(),
  ip: req.ip || null,
});

async function getByStatus(req, res, next) {
  try { res.json(await service.getByStatus(req.query.status)); }
  catch (err) { next(err); }
}

async function submit(req, res, next) {
  try { res.json(await service.submit(req.params.id, req.body, _meta(req))); }
  catch (err) { next(err); }
}

async function approve(req, res, next) {
  try { res.json(await service.approve(req.params.id, req.body, _meta(req))); }
  catch (err) { next(err); }
}

async function reject(req, res, next) {
  try { res.json(await service.reject(req.params.id, req.body, _meta(req))); }
  catch (err) { next(err); }
}

async function getApprovalLog(req, res, next) {
  try {
    res.json(await service.getApprovalLog(req.query.ref_table, req.query.ref_id));
  }
  catch (err) { next(err); }
}

module.exports = { getByStatus, submit, approve, reject, getApprovalLog };
