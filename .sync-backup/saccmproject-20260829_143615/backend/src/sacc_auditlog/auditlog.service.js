const db = require('../configs/db.config');

/**
 * บันทึก Audit Log ทุกการเปลี่ยนแปลงข้อมูล
 * @param {object} params
 * @param {string} params.tablename
 * @param {number} params.record_id
 * @param {string} params.action - INSERT | UPDATE | DELETE
 * @param {string} [params.old_data]
 * @param {string} [params.new_data]
 * @param {number} [params.user_id]
 * @param {string} [params.user_name]
 * @param {string} [params.ip_address]
 */
async function writeAuditLog(params) {
  try {
    await db('audit_log').insert({
      tablename: params.tablename,
      record_id: params.record_id || null,
      action: params.action,
      old_data: params.old_data || null,
      new_data: params.new_data || null,
      user_id: params.user_id || null,
      user_name: params.user_name || null,
      ip_address: params.ip_address || null,
    });
  } catch (err) {
    // ไม่ throw error เพื่อไม่กระทบ business logic หลัก
    console.error('[AuditLog] บันทึก audit log ไม่สำเร็จ:', err.message);
  }
}

/**
 * Express middleware: บันทึก audit log อัตโนมัติหลัง mutation (POST/PATCH/DELETE)
 * ใช้งาน: router.post('/', auditMiddleware('income'), controller.create)
 */
function auditMiddleware(tablename) {
  return function (req, res, next) {
    const originalJson = res.json.bind(res);
    res.json = function (data) {
      if (['POST', 'PATCH', 'DELETE'].includes(req.method) && data?.status === 'successfully') {
        writeAuditLog({
          tablename,
          record_id: data.id || data.lastId || data.lastid || null,
          action: req.method === 'POST' ? 'INSERT' : req.method === 'DELETE' ? 'DELETE' : 'UPDATE',
          new_data: req.method !== 'DELETE' ? JSON.stringify(req.body) : null,
          user_id: req.body?.actor_id || null,
          user_name: req.body?.actor_name || null,
          ip_address: req.ip || null,
        });
      }
      return originalJson(data);
    };
    next();
  };
}

async function getLogs(query = {}) {
  const page = Math.max(1, parseInt(query.page, 10) || 1);
  const perPageRaw = parseInt(query.perPage, 10) || parseInt(query.limit, 10) || 200;
  const perPage = Math.min(500, Math.max(1, perPageRaw));
  const changedField = (query.changed_field || '').toString().trim().toLowerCase();

  let q = db('audit_log').orderBy('created', 'desc');
  if (query.tablename) q = q.where('tablename', query.tablename);
  if (query.record_id) q = q.where('record_id', query.record_id);
  if (query.action) q = q.where('action', query.action);
  if (changedField === 'isactive') {
    q = q.where(function whereIsActiveChange() {
      this.where(function whereOldHasIsActive() {
        this.whereNotNull('old_data').andWhere('old_data', 'like', '%"isactive"%');
      }).orWhere(function whereNewHasIsActive() {
        this.whereNotNull('new_data').andWhere('new_data', 'like', '%"isactive"%');
      });
    });
  }
  if (query.user_name) {
    q = q.whereRaw('LOWER(user_name) LIKE LOWER(?)', [`%${query.user_name}%`]);
  }
  if (query.date_from) q = q.where('created', '>=', query.date_from);
  if (query.date_to) q = q.where('created', '<=', query.date_to + ' 23:59:59');

  const countRow = await q.clone().clearSelect().count({ total: '*' }).first();
  const total = parseInt(countRow?.total, 10) || 0;
  const rows = await q.offset((page - 1) * perPage).limit(perPage);
  return {
    data: rows,
    meta: {
      page,
      perPage,
      total,
      totalPages: Math.ceil(total / perPage),
      changedField: changedField || null,
    },
  };
}

module.exports = { writeAuditLog, auditMiddleware, getLogs };
