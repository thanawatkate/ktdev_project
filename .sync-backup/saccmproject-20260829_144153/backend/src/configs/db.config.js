/**
 * Proxy Knex — อ่าน connection จาก school-db-context ต่อ request
 * (รองรับ server กลางหลายโรงเรียน)
 */
const { getActiveDb } = require('../utils/school-db-context');

function callActiveDb(...args) {
  return getActiveDb()(...args);
}

const handler = {
  apply(_target, _thisArg, args) {
    return callActiveDb(...args);
  },
  get(_target, prop) {
    const db = getActiveDb();
    const value = db[prop];
    if (typeof value === 'function') {
      return value.bind(db);
    }
    return value;
  },
};

module.exports = new Proxy(callActiveDb, handler);
