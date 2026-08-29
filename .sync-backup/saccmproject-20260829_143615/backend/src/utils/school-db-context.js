/**
 * AsyncLocalStorage — สลับ Knex connection ต่อ request ตามโรงเรียน
 */
const { AsyncLocalStorage } = require('async_hooks');
const knex = require('knex');
const knexfile = require('../../knexfile');
const { getSchoolKnex } = require('./school-db.factory');

const storage = new AsyncLocalStorage();

let defaultDb;

function getDefaultDb() {
  if (!defaultDb) {
    const env = process.env.NODE_ENV || 'development';
    defaultDb = knex(knexfile[env]);
  }
  return defaultDb;
}

function getActiveDb() {
  const store = storage.getStore();
  if (store?.schoolDb) return store.schoolDb;
  return getDefaultDb();
}

function runWithSchoolDb(schoolDb, fn) {
  return storage.run({ schoolDb }, fn);
}

function runWithSchoolDbName(dbName, fn) {
  return runWithSchoolDb(getSchoolKnex(dbName), fn);
}

function extractSchoolCodeFromPayload(payload) {
  if (!payload || typeof payload !== 'object') return null;
  return payload.schoolCode || payload.school_code || null;
}

module.exports = {
  storage,
  getDefaultDb,
  getActiveDb,
  runWithSchoolDb,
  runWithSchoolDbName,
  extractSchoolCodeFromPayload,
};
