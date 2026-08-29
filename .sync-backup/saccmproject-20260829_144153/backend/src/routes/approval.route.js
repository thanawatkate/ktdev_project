const express = require('express');
const router = express.Router();
const controller = require('../sacc_approval/controllers/approval.controller');
const { requireAuth } = require('../middleware/auth.middleware');

router.use(requireAuth);

// ดึงรายการใบขอเบิกตามสถานะ (?status=pending|approved|rejected|all)
router.get('/', controller.getByStatus);

// ประวัติการอนุมัติ (?ref_table=expensereq&ref_id=1)
router.get('/log', controller.getApprovalLog);

// ส่งขออนุมัติ
router.post('/:id/submit', controller.submit);

// อนุมัติ
router.post('/:id/approve', controller.approve);

// ปฏิเสธ
router.post('/:id/reject', controller.reject);

module.exports = router;
