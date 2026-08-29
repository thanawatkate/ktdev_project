const svc = require('../services/pdf_form.service');

/**
 * ส่งคืน PDF stream สำหรับแบบฟอร์มต่าง ๆ
 * รับข้อมูลผ่าน body (POST) เพื่อรองรับข้อมูลขนาดใหญ่ + พิเศษ
 */
async function postReceiptSubstitute(req, res, next) {
  try { await svc.generateReceiptSubstitute(req.body || {}, res); }
  catch (err) { next(err); }
}

async function postVoucherReceive(req, res, next) {
  try { await svc.generateVoucherReceive(req.body || {}, res); }
  catch (err) { next(err); }
}

async function postWithholdingTax(req, res, next) {
  try { await svc.generateWithholdingTax(req.body || {}, res); }
  catch (err) { next(err); }
}

async function postReceiptAttachment(req, res, next) {
  try { await svc.generateReceiptAttachment(req.body || {}, res); }
  catch (err) { next(err); }
}

async function postDepositRegister(req, res, next) {
  try { await svc.generateDepositRegister(req.body || {}, res); }
  catch (err) { next(err); }
}

async function postLoanContract(req, res, next) {
  try { await svc.generateLoanContract(req.body || {}, res); }
  catch (err) { next(err); }
}

module.exports = {
  postReceiptSubstitute,
  postVoucherReceive,
  postWithholdingTax,
  postReceiptAttachment,
  postDepositRegister,
  postLoanContract,
};
