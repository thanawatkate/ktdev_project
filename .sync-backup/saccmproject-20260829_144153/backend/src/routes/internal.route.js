const express = require('express');
const router = express.Router();
const { provisionSchoolFromRegistry } = require('../sacc_internal/services/school_provision.service');

function checkInternalSecret(req, res) {
  const secret = process.env.INTERNAL_API_SECRET;
  if (!secret || req.headers['x-internal-secret'] !== secret) {
    res.status(401).json({ success: false, message: 'Unauthorized internal' });
    return false;
  }
  return true;
}

/** POST /saccapi/internal/school/provision — เรียกจาก Registry เท่านั้น */
router.post('/school/provision', async (req, res) => {
  if (!checkInternalSecret(req, res)) return;

  try {
    const result = await provisionSchoolFromRegistry(req.body);
    const code = result.success ? 200 : 400;
    res.status(code).json(result);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
