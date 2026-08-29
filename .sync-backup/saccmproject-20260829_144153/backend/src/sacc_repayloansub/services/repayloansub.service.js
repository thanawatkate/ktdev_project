const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const tableName = 'repayloansub'

function parseRows(data) {
  if (!data) return [];
  if (Array.isArray(data)) return data;
  if (typeof data === 'string') return JSON.parse(data);
  return [data];
}

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
  let detail, remark
  if (bodyData.token === "" || typeof bodyData.token === "undefined") {
    let res = {
      status: 'error',
      message: 'Token not found '
    };
    return res

  } else if (bodyData.docno === "" || typeof bodyData.docno === "undefined") {
    let res = {
      status: 'error',
      message: 'docno require '
    };
    return res
  } else if (bodyData.detail !== "" && typeof bodyData.detail !== "undefined") {
    detail = bodyData.detail
  } else if (bodyData.remark !== "" && typeof bodyData.remark !== "undefined") {
    remark = bodyData.remark
  }
  else if (bodyData.refmember === "" || typeof bodyData.refmember === "undefined") {
    let res = {
      status: 'error',
      message: 'refmember require '
    };
    return res
  }
  if (!checkTokenEXP(bodyData.token)) { // token valid
    const rows = parseRows(bodyData.subdata || bodyData.rows || bodyData);
    const refrepayloan = bodyData.refrepayloan || bodyData.refRepayLoan;
    let res = {
      status: 'error',
      message: 'บันทึกข้อมูลไม่สำเร็จ'
    };
    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];
      const result = await db(tableName).insert({
        refrepayloan,
        refincometype: row.refincometype ?? row.refIncomeType ?? null,
        amount: row.amount,
        remark: row.remark || '',
      });
      const insertedId = Array.isArray(result) ? result[0] : result;
      if (insertedId > 0 && index === rows.length - 1) {
        res = {
          status: 'successfully',
          message: 'บันทึกข้อมูลสำเร็จ'
        };
      }
    }
    return res
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
  }

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

  if (!checkTokenEXP(bodyData.token)) { // token valid
    let fliedUpdate, name, remark, sort
    if (bodyData.name !== "") {
      name = { name: bodyData.name }
    }
    if (bodyData.remark !== "") {
      remark = { remark: bodyData.remark }
    }
    if (bodyData.sort !== "") {
      sort = { sort: bodyData.sort }
    }

    fliedUpdate = { ...name, ...remark, ...sort }
    let result = await db(tableName).where('id', '=', id).update(fliedUpdate)
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
    let result = await db(tableName).where('id', '=', id).delete()

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
// source main Loan  service
async function createRepayloanSub(mainID, Data) {
  let bodyData = parseRows(Data);
  let res = false
  for (let index = 0; index < bodyData.length; index++) {
    const row = bodyData[index];
    const result = await db(tableName).insert({
      refrepayloan: mainID,
      refincometype: row.refincometype ?? row.refIncomeType ?? null,
      amount: row.amount,
      remark: row.remark || '',
    });
    const insertedId = Array.isArray(result) ? result[0] : result;
    if (insertedId > 0 && index === bodyData.length - 1) {
      res = true
    }
  }
  return res
}

async function updateRepayloanSub(mainID, Data) {
  let bodyData = JSON.parse(Data);
  let res = false
  for (let index = 0; index < bodyData.length; index++) {

    let result = await db(tableName).where('id', '=', id).update({
      refincome: mainID,
      refincometype: bodyData[index]["refincometype"],
      amount: bodyData[index]["amount"],
      remark: bodyData[index]["remark"]
    })
    if (result[0].insertId > 0 && index === bodyData.length - 1) {
      res = true
    }
  }
  return res
}

module.exports = {
  getMultiple,
  create,
  update,
  remove,
  createRepayloanSub,
  updateRepayloanSub
}
