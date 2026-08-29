const db = require('../../configs/db.config');
const masterDb = require('../../utils/school-db-context').getDefaultDb();
const { runWithSchoolDbName } = require('../../utils/school-db-context');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const jwt = require('jsonwebtoken')
require("dotenv").config()
const bcrypt = require('bcrypt');
const { validatePassword } = require('../../utils/haspassword/hashpassword.util');

/** ถอด JWT แบบซิงโครนัส — ห้ามใช้ callback ของ verify เพราะค่าที่ return ตอนเรียกทันทีจะไม่ใช่ payload */
function decodeTokenPayloadSync(token) {
  try {
    return jwt.verify(token, process.env.SECRETKEY);
  } catch (err) {
    return null;
  }
}

function checkToken(token) {
  const data = decodeTokenPayloadSync(token);
  return data || [];
}

function checkTokenEXP(token) {
  // return false = token ยังใช้ได้, true = หมดอายุหรือไม่ถูกต้อง
  const data = decodeTokenPayloadSync(token);
  if (!data || typeof data.exp === 'undefined') {
    return true;
  }
  const dateNow = Math.floor(Date.now() / 1000);
  return data.exp - dateNow < 1;
}


async function resolveActiveSchool(schoolCode) {
  if (!schoolCode) return null;
  return masterDb('school_tenant')
    .where({ school_code: schoolCode, status: 'active' })
    .first();
}

async function createTokenInner(loginData, schoolCode) {
  let token = [];
  const isProduction = process.env.NODE_ENV === 'production';
  const allowDefaultCredentials = process.env.ALLOW_DEFAULT_CREDENTIALS === 'true';
  if (isProduction && !allowDefaultCredentials) {
    const username = String(loginData.username || '').trim();
    const password = String(loginData.password || '');
    const defaultCredential =
      (username === 'admin' && password === 'admin1234') ||
      (username === 'officer' && password === 'officer1234');
    if (defaultCredential) return token;
  }

  const rows = await db('users').where('username', loginData.username).select('*');
  const result = helper.emptyOrRows(rows);
  if (!result.length) return token;

  const resultValidatePasswords = await validatePassword(
    loginData.username + loginData.password,
    result[0].password,
  );
  if (resultValidatePasswords === true) {
    const payload = {
      id: result[0].id,
      username: result[0].username,
      name: result[0].name,
      lastname: result[0].lastname,
      usergroup: result[0].refusergroup,
    };
    if (schoolCode) {
      payload.schoolCode = schoolCode;
    }
    token = {
      token: jwt.sign(payload, process.env.SECRETKEY, {
        expiresIn: '8h',
      }),
    };
  }
  return token;
}

async function createToken(loginData) {
  const schoolCode = loginData.schoolCode || loginData.school_code;
  if (!schoolCode) {
    return createTokenInner(loginData, null);
  }

  const school = await resolveActiveSchool(schoolCode);
  if (!school) {
    return [];
  }

  return runWithSchoolDbName(school.db_name, () =>
    createTokenInner(loginData, school.school_code),
  );
}


module.exports = {
  checkToken,
  createToken,
  checkTokenEXP,
  decodeTokenPayloadSync,
};
