const express = require('express');
const router = express.Router();
const controller = require('../sacc_menu/controllers/menu.controller');
const { requireAuth } = require('../middleware/auth.middleware');

/** GET /saccapi/menu/tree — ตาราง app_menu (parent_id = ซับเมนู) */
router.get('/tree', controller.getTree);

/** GET /saccapi/menu/rows?token= — แถวทั้งหมดสำหรับตั้งค่าเมนู */
router.get('/rows', requireAuth, controller.getRows);

/** PUT /saccapi/menu/bulk — อัปเดต name_th / sort_order / is_active */
router.put('/bulk', requireAuth, controller.putBulk);

module.exports = router;
