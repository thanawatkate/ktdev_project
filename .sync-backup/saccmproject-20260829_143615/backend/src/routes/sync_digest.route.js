const express = require('express');
const router = express.Router();
const db = require('../configs/db.config');
const { requireAuth } = require('../middleware/auth.middleware');
const {
  SYNC_DIGEST_TABLES,
  SYNC_DIGEST_VERSION,
} = require('../constants/sync_digest_tables');

/**
 * ตารางที่ mirror กับ SQLite — คีย์เดียวกับ [SYNC_DIGEST_TABLES]
 * (ไม่รวม paymentmethods: ไม่ mount route ใน index)
 */
const DIGEST_TABLES = SYNC_DIGEST_TABLES;

/**
 * GET /saccapi/sync/digest?token=...
 * คืน { success, counts: { tableName: number } } สำหรับเทียบกับ localdb
 */
router.get('/digest', requireAuth, async (req, res) => {
  const counts = {};
  for (const key of DIGEST_TABLES) {
    try {
      let row;
      if (key === 'pay_cheque') {
        try {
          row = await db('paycheque').count({ c: '*' }).first();
        } catch (_) {
          row = await db('saccpaycheque').count({ c: '*' }).first();
        }
      } else if (key === 'budget_source_budget') {
        row = await db('budgetsource').count({ c: '*' }).first();
      } else if (key === 'income_type_budget_source_map') {
        row = await db('income_type_budget_source_map').count({ c: '*' }).first();
      } else {
        row = await db(key).count({ c: '*' }).first();
      }
      const raw = row?.c ?? row?.['count(*)'];
      const n = typeof raw === 'string' ? parseInt(raw, 10) : Number(raw);
      counts[key] = Number.isFinite(n) ? n : 0;
    } catch (_) {
      counts[key] = -1;
    }
  }

  return res.json({
    success: true,
    digestVersion: SYNC_DIGEST_VERSION,
    counts,
  });
});

module.exports = router;
