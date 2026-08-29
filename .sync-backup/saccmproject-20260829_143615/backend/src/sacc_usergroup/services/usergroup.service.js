const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db('usergroup')
    .select('id', 'nameen', 'nameth')
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

  if (bodyData.token === "") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res

  } else if (bodyData.nameth === "" || typeof bodyData.nameth === "undefined") {
    let res = {
      status: 'error',
      message: 'nameth require '
    };
    return res
  } else if (bodyData.nameen === "" || typeof bodyData.nameen === "undefined") {
    let res = {
      status: 'error',
      message: 'nameen require '
    };
    return res
  }

  if (!checkTokenEXP(bodyData.token)) { // token valid

    const result = await db('usergroup').insert({
      nameth: bodyData.nameth,
      nameen: bodyData.nameen,
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

  if (bodyData.token === "" || typeof bodyData.token === "undefined") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res

  } else if (bodyData.nameth === "" || typeof bodyData.nameth === "undefined") {
    let res = {
      status: 'error',
      message: 'nameth require '
    };
    return res
  } else if (bodyData.nameen === "" || typeof bodyData.nameen === "undefined") {
    let res = {
      status: 'error',
      message: 'nameen require '
    };
    return res
  }

  if (!checkTokenEXP(bodyData.token)) { // token valid
    let result = await db("usergroup").where('id', '=', id).update({
      nameen: bodyData.nameen,
      nameth: bodyData.nameth
    })
    let res = {
      status: 'successfully',
      message: result
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
    let result = await db("usergroup").where('id', '=', id).delete()
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
