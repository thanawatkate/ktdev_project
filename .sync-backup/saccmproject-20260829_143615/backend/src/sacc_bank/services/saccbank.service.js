const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const tableName = 'saccbank'

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db(tableName)
    .select('*')
    .orderBy('id', 'asc')
    .limit(config.listPerPage)
    .offset(offset);
  const data = helper.emptyOrRows(rows);
  const meta = { page };
  return {
    data,
    meta
  }
}

async function create(bodyData) {
  if (bodyData.token === "" || typeof bodyData.token === "undefined") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res
  } else if (bodyData.name === "" || typeof bodyData.name === "undefined") {
    let res = {
      status: 'error',
      message: 'name  require '
    };
    return res
  } else if (bodyData.shortname === "" || typeof bodyData.shortname === "undefined") {
    let res = {
      status: 'error',
      message: 'shortname require '
    };
    return res
  }

  if (!checkTokenEXP(bodyData.token)) { // token valid
    const result = await db(tableName).insert({
      name: bodyData.name,
      shortname: bodyData.shortname,
    });
    let res = {
      status: 'error',
      message: 'บันทึกข้อมูลไม่สำเร็จ'
    }
    const insertedId = Array.isArray(result) ? result[0] : result;
    if (insertedId > 0) {
      res = {
        status: 'successfully',
        message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
        lastid: insertedId
      };
    }
    return res;

  } else {
    let res = {
      status: 'error',
      message: 'Token exp '
    };
    return (res)
  }
}

async function update(id, bodyData) {

  let fliedData, shortname, name

  if (id === "" || typeof id === 'undefined') {
    let res = {
      status: 'error',
      message: 'id ข้อมูลไม่ควรเป็นค่าว่าง'
    };
    return (res)
  }

  // check id 
  let result = await db(tableName).where('id', '=', id).select()
  if (result.length < 1) {
    let res = {
      status: 'error',
      message: 'id ไม่มีในระบบกรุณาตราจสอบใหม่อีกครั้ง...'
    };
    return (res)
  }

  if (bodyData.token === "" || typeof bodyData.token === "undefined") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res

  } else if (bodyData.name !== "" && typeof bodyData.name !== "undefined") {
    name = {
      name: bodyData.name
    };

  } else if (bodyData.shortname !== "" && typeof bodyData.shortname !== "undefined") {
    shortname = {
      shortname: bodyData.shortname
    };
  }
  fliedData = { ...name, ...shortname }
  if (!checkTokenEXP(bodyData.token)) { // token valid
    let result = await db(tableName).where('id', '=', id).update(fliedData)
    let res = {
      status: 'successfully',
      message: fliedData
    };
    return res
  }
}

async function remove(id, bodyData) {
  if (id === "" || typeof id === 'undefined') {
    let res = {
      status: 'error',
      message: 'id ข้อมูลไม่ควรเป็นค่าว่าง'
    };
    return (res)
  }
  console.log(id)
  if (!checkTokenEXP(bodyData.token)) { // token valid
    let result = await db(tableName).where('id', '=', id).delete()
    console.log(result)
    if (result > 0) {
      let res = {
        status: 'successfully',
        message: 'ลบข้อมูลเรียบร้อย'
      };
      return (res)
    } else {
      let res = {
        status: 'unsuccessful',
        message: 'ข้อมูลไม่ถูกต้องกรุณาส่งข้อมูล id ที่มีในระบบมาด้วยครับ'
      };
      return (res)
    }
  } else { // true  = Token exp
    let res = {
      status: 'error',
      message: 'Token exp '
    };
    return (res)
  }
}

module.exports = {
  getMultiple,
  create,
  update,
  remove
}
