const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db('member')
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
  } else if (bodyData.code === "" || typeof bodyData.code === "undefined") {
    let res = {
      status: 'error',
      message: 'code  require '
    };
    return res
  } else if (bodyData.name === "" || typeof bodyData.name === "undefined") {
    let res = {
      status: 'error',
      message: 'name require '
    };
    return res
  } else if (bodyData.lastname === "" || typeof bodyData.lastname === "undefined") {
    let res = {
      status: 'error',
      message: 'lastname require '
    };
    return res
  } else if (bodyData.email === "" || typeof bodyData.email === "undefined") {
    let res = {
      status: 'error',
      message: 'email require '
    };
    return res
  } else if (bodyData.contactnumber === "" || typeof bodyData.contactnumber === "undefined") {
    let res = {
      status: 'error',
      message: 'contactnumber require '
    };
    return res
  } else if (bodyData.address === "" || typeof bodyData.address === "undefined") {
    let res = {
      status: 'error',
      message: 'address require '
    };
    return res
  }
  else if (bodyData.refprefix === "" || typeof bodyData.refprefix === "undefined") {
    let res = {
      status: 'error',
      message: 'refprefix require '
    };
    return res
  }

  if (!checkTokenEXP(bodyData.token)) { // token valid
    const result = await db('member').insert({
      code: bodyData.code,
      email: bodyData.email,
      name: bodyData.name,
      lastname: bodyData.lastname,
      contactnumber: bodyData.contactnumber,
      address: bodyData.address,
      refprefix: bodyData.refprefix,
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

  let fliedData, code, name, lastname, email, contactnumber, address, refprefix

  if (id === "" || typeof id === 'undefined') {
    let res = {
      status: 'error',
      message: 'id ข้อมูลไม่ควรเป็นค่าว่าง'
    };
    return (res)
  }

  // check id 
  let result = await db("member").where('id', '=', id).select()
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

  } else if (bodyData.code !== "" && typeof bodyData.code !== "undefined") {
    code = {
      code: bodyData.code
    };

  } else if (bodyData.name !== "" && typeof bodyData.name !== "undefined") {
    name = {
      name: bodyData.name
    };

  } else if (bodyData.lastname !== "" || typeof bodyData.lastname !== "undefined") {
    lastname = {
      lastname: bodyData.lastname
    };
    return res
  } else if (bodyData.email !== "" || typeof bodyData.email !== "undefined") {
    email = {
      email: bodyData.email

    }
  } else if (bodyData.contactnumber !== "" || typeof bodyData.contactnumber !== "undefined") {
    contactnumber = {
      contactnumber: bodyData.contactnumber
    };
  } else if (bodyData.address !== "" || typeof bodyData.address !== "undefined") {
    address = {
      status: bodyData.address
    };
    return res
  } else if (bodyData.refprefix !== "" || typeof bodyData.refprefix !== "undefined") {
    refprefix = {
      ref_prefix: bodyData.refprefix
    };
    return res
  }
  fliedData = { ...code, ...name, ...lastname, ...email, ...address, ...refprefix }
  if (!checkTokenEXP(bodyData.token)) { // token valid
    let result = await db("member").where('id', '=', id).update(fliedData)
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
    let result = await db("member").where('id', '=', id).delete()
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
