const db = require('../../configs/db.config');
const {
  checkTokenEXP,
  decodeTokenPayloadSync,
} = require('../../sacc_login/services/login.service');

function mapNode(row) {
  return {
    id: row.id,
    parent_id: row.parent_id,
    slug: row.slug,
    name_th: row.name_th,
    name_en: row.name_en,
    route_key: row.route_key,
    required_permission: row.required_permission,
    icon_key: row.icon_key,
    sort_order: row.sort_order ?? 0,
    nav_index: row.nav_index != null ? Number(row.nav_index) : null,
    is_active: Boolean(row.is_active),
    submenus: [],
  };
}

function buildTree(rows) {
  const byParent = new Map();
  for (const row of rows) {
    const pid = row.parent_id == null ? '__root__' : row.parent_id;
    if (!byParent.has(pid)) byParent.set(pid, []);
    byParent.get(pid).push(row);
  }
  for (const [, list] of byParent) {
    list.sort((a, b) => {
      const c = (a.sort_order ?? 0) - (b.sort_order ?? 0);
      if (c !== 0) return c;
      return a.id - b.id;
    });
  }
  const roots = byParent.get('__root__') || [];

  function walk(row) {
    const node = mapNode(row);
    const kids = byParent.get(row.id) || [];
    node.submenus = kids.map(walk);
    return node;
  }

  return roots.map(walk);
}

/**
 * โหลดเมนูจากตารางเดียว app_menu (parent_id = ชั้นซับเมนู)
 */
async function getTree() {
  const rows = await db('app_menu')
    .where((qb) => qb.where('is_active', 1).orWhere('is_active', true))
    .orderByRaw('parent_id IS NULL DESC')
    .orderBy('parent_id', 'asc')
    .orderBy('sort_order', 'asc')
    .orderBy('id', 'asc');
  return buildTree(rows);
}

/** แถวทั้งหมด (รวมปิดใช้งาน) — สำหรับหน้าตั้งค่าเมนู */
async function getAllRows() {
  return db('app_menu')
    .select('*')
    .orderByRaw('parent_id IS NULL DESC')
    .orderBy('parent_id', 'asc')
    .orderBy('sort_order', 'asc')
    .orderBy('id', 'asc');
}

async function userHasMenuConfigure(token) {
  if (!token || typeof token !== 'string') return false;
  if (checkTokenEXP(token)) return false;
  const payload = decodeTokenPayloadSync(token);
  if (!payload || payload.id == null) return false;
  let gid = payload.usergroup ?? payload.userGroup;
  if (gid == null || gid === '') {
    const u = await db('users').where('id', payload.id).first();
    gid = u?.refusergroup ?? u?.ref_usergroup;
  }
  gid = Number(gid);
  if (!Number.isFinite(gid)) return false;
  const row = await db('usergroup_permission')
    .where({ usergroup_id: gid, permission_key: 'menu.configure' })
    .first();
  return Boolean(row);
}

/**
 * อัปเดตเฉพาะ name_th, sort_order, is_active ตาม id (ไม่แก้ slug / nav_index / parent)
 * @param {string} token
 * @param {Array<{ id: number, name_th: string, sort_order: number, is_active: number|boolean }>} rows
 */
async function bulkUpdate(token, rows) {
  if (checkTokenEXP(token)) {
    return { ok: false, status: 401, message: 'Token หมดอายุหรือไม่ถูกต้อง' };
  }
  if (!(await userHasMenuConfigure(token))) {
    return { ok: false, status: 403, message: 'ไม่มีสิทธิ์แก้ไขเมนู' };
  }
  if (!Array.isArray(rows) || rows.length === 0) {
    return { ok: false, status: 400, message: 'ต้องส่ง rows เป็นอาร์เรย์' };
  }

  const trx = await db.transaction();
  try {
    for (const r of rows) {
      const id = Number(r.id);
      if (!Number.isFinite(id)) {
        throw new Error('id ไม่ถูกต้อง');
      }
      const nameTh = String(r.name_th ?? '').trim();
      if (nameTh.length === 0 || nameTh.length > 255) {
        throw new Error(`ชื่อเมนูต้องมีความยาว 1–255 ตัวอักษร (id ${id})`);
      }
      const sortOrder = Number(r.sort_order ?? 0);
      if (!Number.isFinite(sortOrder) || sortOrder < 0) {
        throw new Error(`sort_order ไม่ถูกต้อง (id ${id})`);
      }
      const isActive =
        r.is_active === true || r.is_active === 1 || r.is_active === '1'
          ? 1
          : 0;
      const n = await trx('app_menu').where('id', id).update({
        name_th: nameTh,
        sort_order: sortOrder,
        is_active: isActive,
        last_modified: trx.fn.now(),
      });
      if (n === 0) {
        throw new Error(`ไม่พบเมนู id ${id}`);
      }
    }
    await trx.commit();
    return { ok: true, data: await getAllRows() };
  } catch (e) {
    await trx.rollback();
    return {
      ok: false,
      status: 400,
      message: e.message || String(e),
    };
  }
}

module.exports = {
  getTree,
  getAllRows,
  bulkUpdate,
  userHasMenuConfigure,
};
