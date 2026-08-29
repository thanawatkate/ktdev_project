

const db = require('../../configs/db.config');
const helper = require('../../utils/helper.util');
const config = require('../../configs/general.config');
const { checkTokenEXP } = require('../../sacc_login/services/login.service');
const moment = require('moment');

const tableName = 'docgroup'

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
  } else if (bodyData.tablename === "" || typeof bodyData.tablename === "undefined") {
    let res = {
      status: 'error',
      message: 'tablename require '
    };
    return res
  } else if (bodyData.rungroup === "" || typeof bodyData.rungroup === "undefined") {
    let res = {
      status: 'error',
      message: 'rungroup require '
    };
    return res
  }
  else if (bodyData.docnoformat === "" || typeof bodyData.docnoformat === "undefined") {
    let res = {
      status: 'error',
      message: 'docnoformat require '
    };
    return res
  }

  if (!checkTokenEXP(bodyData.token)) { // token valid
    const result = await db(tableName).insert({
      name: bodyData.name,
      tablename: bodyData.tablename,
      rungroup: bodyData.rungroup,
      docnoformat: bodyData.docnoformat,
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

async function createdocno(bodyData) {
  if (bodyData.tablename === "" || typeof bodyData.tablename === "undefined") {
    let res = {
      status: 'error',
      message: 'tablename not found '
    };
    return res
  }
  if (bodyData.docdate === "" || typeof bodyData.docdate === "undefined") {
    let res = {
      status: 'error',
      message: 'docdate not found ex:2024/05/11'
    };
    return res
  }

  // Validate tablename against known tables to prevent SQL injection
  const ALLOWED_TABLES = ['income', 'expense', 'expensereq', 'loan', 'repayloan', 'paycheque'];
  const targetTable = bodyData.tablename.toString().trim().toLowerCase();
  if (!ALLOWED_TABLES.includes(targetTable)) {
    return { status: 'error', message: 'tablename ไม่ถูกต้อง' };
  }

  const rows = await db(tableName).where('tablename', targetTable).limit(1);
  const data = helper.emptyOrRows(rows);
  let docnoformat = data[0].docnoformat

  const chapCount = docnoformat.length - docnoformat.replaceAll('#', '').length;
  const atCount = docnoformat.length - docnoformat.replaceAll('@', '').length;
  const rungroupForReturn = data[0].rungroup.substring(0, chapCount)
  const dateFormatNew = docnoformat.substring(chapCount, docnoformat.length - atCount);
  const dateForReturn = moment(bodyData.docdate).format(dateFormatNew);
  // check last docno 
  const rowsLastDocno = await db(targetTable)
    .where('docno', 'like', `${rungroupForReturn}${dateForReturn}%`)
    .orderBy('id', 'desc')
    .limit(1);
  const dataLastDocno = helper.emptyOrRows(rowsLastDocno);
  let docnoReturn
  if (dataLastDocno.length > 0) {
    const dataLastDocnoSub = dataLastDocno[0].docno.substring(docnoformat.length - atCount, docnoformat.length);
    let number = Number(dataLastDocnoSub) + 1;
    let formattedNumber = number.toString().padStart(atCount, '0')
    docnoReturn = rungroupForReturn + dateForReturn + formattedNumber

  } else {
    let number = 1; // Example number 
    let formattedNumber = number.toString().padStart(atCount, '0');
    docnoReturn = rungroupForReturn + dateForReturn + formattedNumber
  }
  return docnoReturn
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
  remove, createdocno
}
