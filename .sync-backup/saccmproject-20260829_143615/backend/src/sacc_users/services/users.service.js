const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { hashPassword } = require('../../utils/haspassword/hashpassword.util');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');

async function getMultiple(page = 1) {
  const offset = helper.getOffset(page, config.listPerPage);
  const rows = await db('users')
    .select(
      'id',
      'code',
      'email',
      'username',
      'name',
      'lastname',
      'contactnumber',
      'refusergroup',
      'refprefix',
      'created',
      'updated',
    )
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
  //check data 
  if (bodyData.token === "") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res

  } else if (bodyData.refusergroup === "" || typeof bodyData.refusergroup === "undefined") {
    let res = {
      status: 'error',
      message: 'refusergroup require '
    };
    return res
  } else if (bodyData.refprefix === "" || typeof bodyData.refprefix === "undefined") {
    let res = {
      status: 'error',
      message: 'refprefix require '
    };
    return res
  } else if (bodyData.username === "" || typeof bodyData.username === "undefined") {
    let res = {
      status: 'error',
      message: 'username require '
    };
    return res
  } else if (bodyData.password === "" || typeof bodyData.password === "undefined") {
    let res = {
      status: 'error',
      message: 'password require '
    };
    return res
  } else if (bodyData.code === "" || typeof bodyData.code === "undefined") {
    let res = {
      status: 'error',
      message: 'code require '
    };
    return res
  } else if (bodyData.email === "" || typeof bodyData.email === "undefined") {
    let res = {
      status: 'error',
      message: 'email require '
    };
    return res
  }
  if (!checkTokenEXP(bodyData.token)) { // token valid
    let newPassword = await hashPassword(bodyData.username + bodyData.password).then(result => {
      return result
    });
    const result = await db('users').insert({
      code: bodyData.code,
      email: bodyData.email,
      password: newPassword,
      name: bodyData.name,
      username: bodyData.username,
      lastname: bodyData.lastname,
      contactnumber: bodyData.contactnumber,
      refusergroup: bodyData.refusergroup,
      refprefix: bodyData.refprefix,
    });
    let res = {
      status: 'error',
      message: 'บันทึกข้อมูลไม่สำเร็จ'
    }
    const insertId = Array.isArray(result) ? result[0] : result;
    if (insertId > 0) {
      res = {
        status: 'successfully',
        message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
        lastid: insertId
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
  // console.log(id) 
  if (bodyData.token === "" || typeof bodyData.token === "undefined") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res

  } else if (bodyData.refusergroup === "" || typeof bodyData.refusergroup === "undefined") {
    let res = {
      status: 'error',
      message: 'refusergroup require '
    };
    return res
  } else if (bodyData.refprefix === "" || typeof bodyData.refprefix === "undefined") {
    let res = {
      status: 'error',
      message: 'refprefix require '
    };
    return res
  } else if (bodyData.code === "" || typeof bodyData.code === "undefined") {
    let res = {
      status: 'error',
      message: 'code require '
    };
    return res
  } else if (bodyData.email === "" || typeof bodyData.email === "undefined") {
    let res = {
      status: 'error',
      message: 'email require '
    };
    return res
  }

  if (!checkTokenEXP(bodyData.token)) { // token valid

    let result = await db("users").where('id', '=', id).update({
      code: bodyData.code,
      email: bodyData.email,
      name: bodyData.name,
      lastname: bodyData.lastname,
      contactnumber: bodyData.contactnumber,
      refusergroup: bodyData.refusergroup,
      refprefix: bodyData.refprefix
    })


    let res = {
      status: 'successfully',
      message: result
    };
    return res

  } else { // true  = Token exp
    let res = {
      status: 'error',
      message: 'Token exp '
    };
    return (res)
  }

}

async function remove(id, bodyData) {
  if (!checkTokenEXP(bodyData.token)) { // token valid
    let result = await db("users").where('id', '=', id).delete()
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
