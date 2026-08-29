const service = require('../services/menu.service');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

async function getTree(req, res, next) {
  try {
    const data = await service.getTree();
    res.json({ success: true, data });
  } catch (err) {
    console.error('menu.getTree', err.message);
    next(err);
  }
}

/** GET /menu/rows?token= — แถว flat ทั้งหมด (ต้องมีสิทธิ์ menu.configure) */
async function getRows(req, res, next) {
  try {
    const token = req.query.token;
    if (!token || checkTokenEXP(token)) {
      return res.status(401).json({ success: false, message: 'Token หมดอายุหรือไม่ถูกต้อง' });
    }
    if (!(await service.userHasMenuConfigure(token))) {
      return res.status(403).json({ success: false, message: 'ไม่มีสิทธิ์แก้ไขเมนู' });
    }
    const data = await service.getAllRows();
    res.json({ success: true, data });
  } catch (err) {
    console.error('menu.getRows', err.message);
    next(err);
  }
}

/** PUT /menu/bulk body: { token, rows } */
async function putBulk(req, res, next) {
  try {
    const token = req.body?.token;
    const rows = req.body?.rows;
    const result = await service.bulkUpdate(token, rows);
    if (!result.ok) {
      return res.status(result.status).json({ success: false, message: result.message });
    }
    res.json({ success: true, data: result.data });
  } catch (err) {
    console.error('menu.putBulk', err.message);
    next(err);
  }
}

module.exports = {
  getTree,
  getRows,
  putBulk,
};
