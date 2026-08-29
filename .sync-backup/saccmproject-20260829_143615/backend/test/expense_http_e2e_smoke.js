require('dotenv').config();
const jwt = require('jsonwebtoken');
const db = require('../src/configs/db.config');
const { assertSafeE2EDatabase } = require('./e2e_db_safety');

assertSafeE2EDatabase();

async function main() {
  const baseUrl = process.env.E2E_BASE_URL || `http://localhost:${process.env.PORT || 3800}/saccapi`;
  const token = jwt.sign(
    { id: 1, username: 'e2e-smoke' },
    process.env.SECRETKEY,
    { expiresIn: '1h' },
  );

  let expenseId = null;
  let createdBudgetSourceId = null;
  let createdPartyId = null;
  try {
    let party = await db('party').first('id');
    if (!party) {
      const inserted = await db('party').insert({
        name: 'ผู้รับเงินทดสอบ-http-smoke',
        role: 'receiver',
        isactive: 1,
      });
      party = { id: Array.isArray(inserted) ? inserted[0] : inserted };
      createdPartyId = party.id;
    }
    let budgetSource = await db('budgetsource').where('use', 'Y').first('id');
    if (!budgetSource) {
      const inserted = await db('budgetsource').insert({
        code: `HTTP-SMOKE-${Date.now()}`,
        name: 'HTTP smoke budget source',
        fiscal_year: '2569',
        budget_amount: 100000,
        budget_type: 'งปม',
        use: 'Y',
      });
      createdBudgetSourceId = Array.isArray(inserted) ? inserted[0] : inserted;
      budgetSource = { id: createdBudgetSourceId };
    }
    const moneyType = await db('moneytype').first('id');
    if (!moneyType) throw new Error('moneytype seed not found');
    const expenseType = await db('expensetype').first('id');

    const docno = `EXP-HTTP-SMOKE-${Date.now()}`;
    const createPayload = {
      token,
      docno,
      docdate: new Date().toISOString().slice(0, 10),
      detail: 'http smoke create',
      remark: 'initial',
      refmember: '',
      refparty: String(party.id),
      refbudgetsource: String(budgetSource.id),
      subdata: JSON.stringify([
        {
          amount: '11.25',
          remark: 'line-a',
          refmoneytype: moneyType.id,
          refexpensetype: expenseType?.id || null,
        },
        {
          amount: '8.75',
          remark: 'line-b',
          refmoneytype: moneyType.id,
          refexpensetype: expenseType?.id || null,
        },
      ]),
      payCheque: JSON.stringify([
        {
          chequeamount: '20.00',
          refchequeaccount: null,
          chequeno: 'CHQ-SMOKE-1',
          remark: 'pc-1',
        },
      ]),
      bankamount: '20',
      money_domain: 'budget',
      doc_status: 'posted',
    };

    const createRes = await fetch(`${baseUrl}/expense`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(createPayload),
    });
    const createJson = await createRes.json();
    if (createRes.status !== 200 || createJson.status !== 'successfully') {
      throw new Error(`create failed: ${createRes.status} ${JSON.stringify(createJson)}`);
    }

    const created = await db('expense').where('docno', docno).first();
    if (!created) throw new Error('created expense not found in DB');
    expenseId = created.id;

    const updatePayload = {
      token,
      detail: 'http smoke update',
      remark: 'updated',
      refparty: String(party.id),
      refbudgetsource: String(budgetSource.id),
      subdata: JSON.stringify([
        {
          amount: '30.00',
          remark: 'line-new',
          refmoneytype: moneyType.id,
          refexpensetype: expenseType?.id || null,
        },
      ]),
      payCheque: JSON.stringify([
        {
          chequeamount: '30.00',
          refchequeaccount: null,
          chequeno: 'CHQ-SMOKE-2',
          remark: 'pc-2',
        },
      ]),
      bankamount: '30',
      money_domain: 'budget',
      doc_status: 'approved',
      change_reason: 'smoke test update reason',
    };

    const updateRes = await fetch(`${baseUrl}/expense/${expenseId}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(updatePayload),
    });
    const updateJson = await updateRes.json();
    if (updateRes.status !== 200 || updateJson.status !== 'successfully') {
      throw new Error(`update failed: ${updateRes.status} ${JSON.stringify(updateJson)}`);
    }

    const exp = await db('expense').where('id', expenseId).first();
    const subs = await db('expensesub').where('refexpense', expenseId);
    const payCheque = await db('paycheque').where('refexpense', expenseId);

    if (exp.doc_status !== 'approved') throw new Error('doc_status mismatch');
    if (exp.money_domain !== 'budget') throw new Error('money_domain mismatch');
    if (exp.change_reason !== 'smoke test update reason') throw new Error('change_reason mismatch');
    if (subs.length !== 1 || String(subs[0].amount) !== '30.00') throw new Error('expense sub replacement mismatch');
    if (payCheque.length !== 1 || payCheque[0].chequeno !== 'CHQ-SMOKE-2') throw new Error('pay cheque replacement mismatch');

    console.log('expense-http-e2e-smoke: PASS');
  } finally {
    if (expenseId) {
      await db('paycheque').where('refexpense', expenseId).delete();
      await db('expensesub').where('refexpense', expenseId).delete();
      await db('expense').where('id', expenseId).delete();
    }
    if (createdBudgetSourceId) {
      await db('budgetsource').where('id', createdBudgetSourceId).delete();
    }
    if (createdPartyId) {
      await db('party').where('id', createdPartyId).delete();
    }
    await db.destroy();
  }
}

main().catch(async (err) => {
  console.error('expense-http-e2e-smoke: FAIL');
  console.error(err.message);
  try {
    await db.destroy();
  } catch (_) {}
  process.exit(1);
});
