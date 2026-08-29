require('dotenv').config();
const jwt = require('jsonwebtoken');
const db = require('../src/configs/db.config');
const { assertSafeE2EDatabase } = require('./e2e_db_safety');

const BASE_URL = process.env.E2E_BASE_URL || `http://localhost:${process.env.PORT || 3800}/saccapi`;

assertSafeE2EDatabase();

async function ensureGroup(nameen, nameth) {
  let row = await db('usergroup').whereRaw('LOWER(nameen) = LOWER(?)', [nameen]).first();
  let created = false;
  if (!row) {
    const inserted = await db('usergroup').insert({ nameen, nameth, use: 'Y' });
    row = { id: Array.isArray(inserted) ? inserted[0] : inserted, nameen };
    created = true;
  }
  return { ...row, _createdByTest: created };
}

async function ensurePermission(groupId, permissionKey) {
  const exists = await db('usergroup_permission')
    .where({ usergroup_id: groupId, permission_key: permissionKey })
    .first();
  if (exists) return false;
  await db('usergroup_permission').insert({ usergroup_id: groupId, permission_key: permissionKey });
  return true;
}

function buildToken(user) {
  return jwt.sign(
    {
      id: user.id,
      username: user.username,
      name: user.name,
      lastname: user.lastname,
      usergroup: user.refusergroup,
    },
    process.env.SECRETKEY,
    { expiresIn: '1h' },
  );
}

async function callJson(url, method, body) {
  const res = await fetch(url, {
    method,
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  return { status: res.status, json };
}

async function main() {
  const created = {
    users: [],
    groups: [],
    reqIds: [],
    permissionRows: [],
  };

  try {
    const submitGroup = await ensureGroup('officer', 'เจ้าหน้าที่');
    const approveGroup = await ensureGroup('approver-test', 'ผู้อนุมัติทดสอบ');
    if (submitGroup._createdByTest) created.groups.push(submitGroup.id);
    if (approveGroup._createdByTest) created.groups.push(approveGroup.id);

    if (await ensurePermission(submitGroup.id, 'nav.expense_req')) {
      created.permissionRows.push({ usergroup_id: submitGroup.id, permission_key: 'nav.expense_req' });
    }
    for (const key of ['approval.approve', 'approval.reject']) {
      if (await ensurePermission(approveGroup.id, key)) {
        created.permissionRows.push({ usergroup_id: approveGroup.id, permission_key: key });
      }
    }

    const ts = Date.now();
    const submitterId = (await db('users').insert({
      code: `T-SUB-${ts}`,
      email: `submitter_${ts}@example.local`,
      username: `submitter_${ts}`,
      password: 'not-used',
      name: 'Submit',
      lastname: 'Tester',
      contactnumber: '0000000000',
      refusergroup: submitGroup.id,
      refprefix: null,
    }))[0];
    created.users.push(submitterId);

    const approverId = (await db('users').insert({
      code: `T-APR-${ts}`,
      email: `approver_${ts}@example.local`,
      username: `approver_${ts}`,
      password: 'not-used',
      name: 'Approve',
      lastname: 'Tester',
      contactnumber: '0000000001',
      refusergroup: approveGroup.id,
      refprefix: null,
    }))[0];
    created.users.push(approverId);

    const submitter = await db('users').where('id', submitterId).first();
    const approver = await db('users').where('id', approverId).first();
    const submitToken = buildToken(submitter);
    const approveToken = buildToken(approver);

    const reqDoc1 = `REQ-APPROVE-${ts}`;
    const reqId1 = (await db('expensereq').insert({
      docno: reqDoc1,
      amount: 0.5,
      remark: 'approval smoke approve',
      refmember: null,
      approval_status: 'draft',
    }))[0];
    created.reqIds.push(reqId1);

    const submitRes1 = await callJson(`${BASE_URL}/approval/${reqId1}/submit`, 'POST', {
      token: submitToken,
      note: 'submit for approval',
    });
    if (submitRes1.status !== 200 || submitRes1.json.status !== 'successfully') {
      throw new Error(`submit failed: ${submitRes1.status} ${JSON.stringify(submitRes1.json)}`);
    }

    const denyApproveRes = await callJson(`${BASE_URL}/approval/${reqId1}/approve`, 'POST', {
      token: submitToken,
      note: 'try self approve',
    });
    if (denyApproveRes.status !== 200 || denyApproveRes.json.status !== 'error') {
      throw new Error(`self-approve denial failed: ${denyApproveRes.status} ${JSON.stringify(denyApproveRes.json)}`);
    }

    const approveRes = await callJson(`${BASE_URL}/approval/${reqId1}/approve`, 'POST', {
      token: approveToken,
      note: 'approved by approver user',
    });
    if (approveRes.status !== 200 || approveRes.json.status !== 'successfully') {
      throw new Error(`approve failed: ${approveRes.status} ${JSON.stringify(approveRes.json)}`);
    }

    const reqDoc2 = `REQ-REJECT-${ts}`;
    const reqId2 = (await db('expensereq').insert({
      docno: reqDoc2,
      amount: 0.75,
      remark: 'approval smoke reject',
      refmember: null,
      approval_status: 'draft',
    }))[0];
    created.reqIds.push(reqId2);

    const submitRes2 = await callJson(`${BASE_URL}/approval/${reqId2}/submit`, 'POST', {
      token: submitToken,
      note: 'submit for reject flow',
    });
    if (submitRes2.status !== 200 || submitRes2.json.status !== 'successfully') {
      throw new Error(`submit(2) failed: ${submitRes2.status} ${JSON.stringify(submitRes2.json)}`);
    }

    const rejectRes = await callJson(`${BASE_URL}/approval/${reqId2}/reject`, 'POST', {
      token: approveToken,
      reject_reason: 'หลักฐานไม่ครบ',
    });
    if (rejectRes.status !== 200 || rejectRes.json.status !== 'successfully') {
      throw new Error(`reject failed: ${rejectRes.status} ${JSON.stringify(rejectRes.json)}`);
    }

    const req1 = await db('expensereq').where('id', reqId1).first();
    const req2 = await db('expensereq').where('id', reqId2).first();
    if (req1.approval_status !== 'approved') throw new Error('approval status mismatch for req1');
    if (Number(req1.approved_by) !== Number(approverId)) throw new Error('approved_by mismatch for req1');
    if (req2.approval_status !== 'rejected') throw new Error('approval status mismatch for req2');
    if (!req2.reject_reason) throw new Error('reject_reason missing for req2');

    const logs1 = await db('approval_log').where({ ref_table: 'expensereq', ref_id: reqId1 }).orderBy('created', 'asc');
    const logs2 = await db('approval_log').where({ ref_table: 'expensereq', ref_id: reqId2 }).orderBy('created', 'asc');
    if (logs1.length < 2) throw new Error('approval log incomplete for req1');
    if (logs2.length < 2) throw new Error('approval log incomplete for req2');

    console.log('approval-http-e2e-smoke: PASS');
  } finally {
    if (created.reqIds.length > 0) {
      await db('approval_log').where('ref_table', 'expensereq').whereIn('ref_id', created.reqIds).delete();
      await db('expensereq').whereIn('id', created.reqIds).delete();
    }
    if (created.users.length > 0) {
      await db('users').whereIn('id', created.users).delete();
    }
    for (const p of created.permissionRows) {
      await db('usergroup_permission').where(p).delete();
    }
    if (created.groups.length > 0) {
      await db('usergroup').whereIn('id', created.groups).delete();
    }
    await db.destroy();
  }
}

main().catch(async (err) => {
  console.error('approval-http-e2e-smoke: FAIL');
  console.error(err.message);
  try { await db.destroy(); } catch (_) {}
  process.exit(1);
});
