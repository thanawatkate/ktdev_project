const ensureDatabaseExists = require('../../utils/ensure-database');
const { getSchoolKnex, seedSchoolBasics } = require('../../utils/school-db.factory');
const { getDefaultDb } = require('../../utils/school-db-context');
const { runWithSchoolDbName } = require('../../utils/school-db-context');
const { getActiveDb } = require('../../utils/school-db-context');
const passwordManage = require('../../utils/haspassword/hashpassword.util');

/**
 * เรียกจาก Registry — สร้าง DB + tenant row + admin user
 */
async function provisionSchoolFromRegistry(body) {
  const {
    schoolCode,
    dbName,
    schoolName,
    adminUsername,
    adminPassword,
    adminName,
    adminLastname,
    adminEmail,
  } = body;

  if (!schoolCode || !dbName) {
    return { success: false, message: 'schoolCode และ dbName จำเป็น' };
  }

  const masterDb = getDefaultDb();

  await ensureDatabaseExists(dbName);
  const schoolKnex = getSchoolKnex(dbName);
  await schoolKnex.migrate.latest();
  await seedSchoolBasics(schoolKnex);

  const existing = await masterDb('school_tenant').where({ school_code: schoolCode }).first();
  const tenantRow = {
    school_code: schoolCode,
    school_name: schoolName || schoolCode,
    db_name: dbName,
    status: 'active',
    updated: masterDb.fn.now(),
  };

  if (existing) {
    await masterDb('school_tenant').where({ id: existing.id }).update(tenantRow);
  } else {
    await masterDb('school_tenant').insert({
      ...tenantRow,
      provisioned_at: masterDb.fn.now(),
    });
  }

  if (adminUsername && adminPassword) {
    await runWithSchoolDbName(dbName, async () => {
      const db = getActiveDb();
      const adminGroup = await db('usergroup').where({ nameen: 'admin' }).first();
      const groupId = adminGroup?.id || 1;
      const user = await db('users').where({ username: adminUsername }).first();
      if (!user) {
        const hashed = await passwordManage.hashPassword(
          adminUsername + adminPassword,
        );
        await db('users').insert({
          code: '01',
          email: adminEmail || `${adminUsername}@school.local`,
          username: adminUsername,
          password: hashed,
          name: adminName || 'ผู้ดูแล',
          lastname: adminLastname || 'ระบบ',
          contactnumber: '',
          refusergroup: groupId,
          refprefix: 1,
        });
      }
    });
  }

  return {
    success: true,
    message: 'provision สำเร็จ',
    schoolCode,
    dbName,
  };
}

module.exports = {
  provisionSchoolFromRegistry,
};
