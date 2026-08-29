const bcrypt = require('bcrypt');
require('dotenv').config();

const DOC_GROUPS = [
  { tablename: 'income', name: 'เลขที่เอกสารรับเงิน', rungroup: 'INC', docnoformat: '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}' },
  { tablename: 'loan', name: 'เลขที่เอกสารยืมเงิน', rungroup: 'LOAN', docnoformat: '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}' },
  { tablename: 'expense_req', name: 'เลขที่ใบขอเบิก', rungroup: 'REQ', docnoformat: '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}' },
  { tablename: 'repay_loan', name: 'เลขที่เอกสารคืนเงินยืม', rungroup: 'REPAY', docnoformat: '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}' },
];

const BANKS = [
  { name: 'ธนาคารกรุงเทพ', shortname: 'BBL', code: '002', sort: 1 },
  { name: 'ธนาคารกรุงไทย', shortname: 'KTB', code: '006', sort: 2 },
  { name: 'ธนาคารกรุงศรีอยุธยา', shortname: 'BAY', code: '025', sort: 3 },
  { name: 'ธนาคารกสิกรไทย', shortname: 'KBANK', code: '004', sort: 4 },
  { name: 'ธนาคารไทยพาณิชย์', shortname: 'SCB', code: '014', sort: 5 },
  { name: 'ธนาคารทหารไทยธนชาต', shortname: 'TTB', code: '011', sort: 6 },
  { name: 'ธนาคารซีไอเอ็มบี ไทย', shortname: 'CIMBT', code: '022', sort: 7 },
  { name: 'ธนาคารยูโอบี', shortname: 'UOB', code: '024', sort: 8 },
  { name: 'ธนาคารแลนด์ แอนด์ เฮ้าส์', shortname: 'LHBANK', code: '073', sort: 9 },
  { name: 'ธนาคารไอซีบีซี (ไทย)', shortname: 'ICBC', code: '070', sort: 10 },
  { name: 'ธนาคารเกียรตินาคินภัทร', shortname: 'KKP', code: '069', sort: 11 },
  { name: 'ธนาคารทิสโก้', shortname: 'TISCO', code: '067', sort: 12 },
  { name: 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร', shortname: 'BAAC', code: '034', sort: 13 },
  { name: 'ธนาคารออมสิน', shortname: 'GSB', code: '030', sort: 14 },
  { name: 'ธนาคารอาคารสงเคราะห์', shortname: 'GHB', code: '033', sort: 15 },
  { name: 'ธนาคารอิสลามแห่งประเทศไทย', shortname: 'iBank', code: '066', sort: 16 },
  { name: 'ธนาคารเพื่อการส่งออกและนำเข้าแห่งประเทศไทย', shortname: 'EXIM', code: '065', sort: 17 },
];

const MONEY_TYPES = [
  { id: 1, name: 'เงินสด', sort: 1 },
  { id: 2, name: 'เงินโอน', sort: 2 },
  { id: 3, name: 'เช็ค', sort: 3 },
  { id: 4, name: 'เงินฝากส่วนราชการผู้เบิก', sort: 4 },
];

const INCOME_TYPES = [
  { code: '01', name: 'เงินอุดหนุนรายหัว', remark: 'เงินอุดหนุนค่าใช้จ่ายในการจัดการศึกษาขั้นพื้นฐาน จัดสรรตามจำนวนนักเรียน', sort: 1 },
  { code: '02', name: 'เงินอุดหนุนอาหารกลางวัน', remark: 'เงินอุดหนุนค่าอาหารกลางวันนักเรียน ระดับก่อนประถม–ประถมศึกษา', sort: 2 },
  { code: '03', name: 'เงินอุดหนุนอาหารเสริม (นม)', remark: 'เงินอุดหนุนโครงการอาหารเสริมนมโรงเรียน', sort: 3 },
  { code: '04', name: 'เงินอุดหนุนโครงการเรียนฟรี 15 ปี', remark: 'ค่าเล่าเรียน ค่าอุปกรณ์การเรียน ค่าชุดนักเรียน ค่ากิจกรรมพัฒนาคุณภาพ', sort: 4 },
  { code: '05', name: 'เงินอุดหนุนเฉพาะกิจ/โครงการพิเศษ', remark: 'เงินอุดหนุนจากหน่วยงานต้นสังกัดหรือภายนอกสำหรับโครงการเฉพาะ', sort: 5 },
  { code: '06', name: 'เงินบริจาคและทรัพย์สิน', remark: 'เงินหรือทรัพย์สินที่ได้รับบริจาคจากผู้ปกครอง ชุมชน หรือองค์กรภายนอก', sort: 6 },
  { code: '07', name: 'เงินรายได้สถานศึกษา', remark: 'รายได้จากการให้บริการ ค่าเช่าพื้นที่ ขายสินค้า กิจกรรมหารายได้', sort: 7 },
  { code: '08', name: 'เงินสมทบจากองค์กรปกครองส่วนท้องถิ่น', remark: 'เงินสนับสนุนจาก อบต. อบจ. เทศบาล หรือหน่วยงานท้องถิ่น', sort: 8 },
  { code: '09', name: 'เงินกู้ยืมเพื่อการศึกษา (กยศ./กรอ.)', remark: 'เงินกู้ยืมที่นักเรียน/นักศึกษาได้รับผ่านกองทุน กยศ. หรือ กรอ.', sort: 9 },
  { code: '10', name: 'รายรับอื่น', remark: 'รายรับที่ไม่จัดอยู่ในประเภทข้างต้น', sort: 10 },
];

const EXPENSE_TYPES = [
  { code: '00', name: 'งบบุคลากร — ค่าจ้างชั่วคราว', remark: 'ค่าจ้างลูกจ้างชั่วคราวจากเงินรายได้สถานศึกษา (รายการที่ 1 ในรายงานหน้า 33)', sort: 0 },
  { code: '01', name: 'ค่าตอบแทน', remark: 'ค่าจ้าง ค่าตอบแทนบุคลากร โบนัส ค่าตอบแทนพิเศษ', sort: 1 },
  { code: '02', name: 'ค่าใช้สอย', remark: 'ค่าเช่า ค่าเดินทาง ค่าจัดงาน ค่าพิมพ์ ค่าบริการ', sort: 2 },
  { code: '03', name: 'ค่าวัสดุ', remark: 'วัสดุสำนักงาน วัสดุการศึกษา วัสดุงานบ้าน อุปกรณ์กีฬา', sort: 3 },
  { code: '04', name: 'ค่าสาธารณูปโภค', remark: 'ค่าน้ำประปา ค่าไฟฟ้า ค่าโทรศัพท์ ค่าอินเทอร์เน็ต', sort: 4 },
  { code: '05', name: 'ค่าครุภัณฑ์', remark: 'คอมพิวเตอร์ เครื่องพิมพ์ เฟอร์นิเจอร์ อุปกรณ์ครุภัณฑ์', sort: 5 },
  { code: '06', name: 'ค่าที่ดินและสิ่งก่อสร้าง', remark: 'ที่ดิน อาคารเรียน ห้องเรียน ซ่อมแซมอาคาร', sort: 6 },
  { code: '07', name: 'เงินอุดหนุน', remark: 'เงินสนับสนุนนักเรียน ทุนการศึกษา เงินช่วยเหลือ', sort: 7 },
  { code: '08', name: 'รายจ่ายอื่น', remark: 'รายจ่ายที่ไม่จัดอยู่ในประเภทข้างต้น', sort: 8 },
];

const APP_MENU_ROWS = [
  { id: 1, parent_id: null, slug: 'section_transactions', name_th: 'ธุรกรรมรับ-จ่าย', name_en: 'section_transactions', route_key: null, required_permission: null, icon_key: null, sort_order: 1, nav_index: null },
  { id: 2, parent_id: 1, slug: 'income', name_th: 'บันทึกรับเงิน', name_en: 'income', route_key: 'income', required_permission: 'nav.income', icon_key: 'south_rounded', sort_order: 0, nav_index: 1 },
  { id: 13, parent_id: 1, slug: 'expense_req', name_th: 'ใบขอเบิก', name_en: 'expense_req', route_key: 'expense_req', required_permission: 'nav.expense_req', icon_key: 'request_quote_outlined', sort_order: 1, nav_index: 11 },
  { id: 3, parent_id: 1, slug: 'expense', name_th: 'เบิกจริง (ใบสำคัญ)', name_en: 'expense', route_key: 'expense', required_permission: 'nav.expense', icon_key: 'north_rounded', sort_order: 2, nav_index: 2 },
  { id: 4, parent_id: 1, slug: 'loan', name_th: 'บันทึกยืมเงิน', name_en: 'loan', route_key: 'loan', required_permission: 'nav.loan', icon_key: 'account_balance_rounded', sort_order: 3, nav_index: 3 },
  { id: 5, parent_id: null, slug: 'section_approval_reports', name_th: 'การอนุมัติเบิกจ่าย', name_en: 'section_approval_expense', route_key: null, required_permission: null, icon_key: null, sort_order: 2, nav_index: null },
  { id: 6, parent_id: 5, slug: 'approval', name_th: 'อนุมัติการเบิก', name_en: 'approval', route_key: 'approval', required_permission: 'approval.view', icon_key: 'task_alt_rounded', sort_order: 0, nav_index: 4 },
  { id: 7, parent_id: 5, slug: 'reports', name_th: 'รายงานการเงิน', name_en: 'reports', route_key: 'reports', required_permission: 'nav.reports', icon_key: 'bar_chart_rounded', sort_order: 1, nav_index: 5 },
  { id: 10, parent_id: null, slug: 'section_register', name_th: 'ทะเบียนคุมและเอกสาร', name_en: 'section_register', route_key: null, required_permission: null, icon_key: null, sort_order: 3, nav_index: null },
  { id: 11, parent_id: 10, slug: 'register', name_th: 'ทะเบียนคุม', name_en: 'register', route_key: 'register', required_permission: 'nav.register', icon_key: 'fact_check_outlined', sort_order: 0, nav_index: 9 },
  { id: 12, parent_id: 10, slug: 'forms', name_th: 'แบบฟอร์มเอกสาร', name_en: 'forms', route_key: 'forms', required_permission: 'nav.forms', icon_key: 'description_outlined', sort_order: 1, nav_index: 10 },
  { id: 8, parent_id: null, slug: 'section_system', name_th: 'ระบบ', name_en: 'section_system', route_key: null, required_permission: null, icon_key: null, sort_order: 4, nav_index: null },
  { id: 9, parent_id: 8, slug: 'usage_guide', name_th: 'คู่มือใช้งาน', name_en: 'usage_guide', route_key: 'usage_guide', required_permission: 'nav.usage_guide', icon_key: 'menu_book_outlined', sort_order: 1, nav_index: 7 },
];

const ADMIN_PERMISSIONS = [
  'nav.home', 'nav.income', 'nav.expense_req', 'nav.expense', 'nav.loan',
  'nav.reports', 'nav.usage_guide', 'nav.logout', 'nav.register', 'nav.forms',
  'approval.view', 'approval.manage', 'approval.approve', 'approval.reject',
  'budget_source.view', 'budget_source.create', 'budget_source.update',
  'budget_source.delete', 'setting.view', 'user_admin.view', 'user_admin.create',
  'user_admin.reset_password', 'user_admin.update_role', 'user_admin.toggle_active',
  'audit_log.view', 'forms.docno.manual_edit', 'menu.configure',
  'register.deposit.view', 'register.deposit.create', 'register.deposit.update',
  'register.deposit.settle', 'register.deposit.delete',
];

const OFFICER_PERMISSIONS = [
  'nav.home', 'nav.income', 'nav.expense_req', 'nav.expense', 'nav.loan',
  'nav.reports', 'nav.usage_guide', 'nav.logout', 'nav.register', 'nav.forms',
  'budget_source.view', 'register.deposit.view',
];

function currentYearBE() {
  return String(new Date().getFullYear() + 543);
}

async function hashPassword(username, password) {
  const saltRounds = Number(process.env.SALTROUNDS) || 10;
  return bcrypt.hash(`${username}${password}`, saltRounds);
}

async function upsertBy(knex, tableName, where, row) {
  const existing = await knex(tableName).where(where).first();
  if (existing) {
    await knex(tableName).where({ id: existing.id }).update(row);
    return existing.id;
  }
  const inserted = await knex(tableName).insert({ ...where, ...row });
  return Array.isArray(inserted) ? inserted[0] : inserted;
}

exports.up = async function (knex) {
  if (await knex.schema.hasTable('docgroup')) {
    for (const row of DOC_GROUPS) {
      await upsertBy(knex, 'docgroup', { tablename: row.tablename }, { ...row, use: 'Y' });
    }
  }

  if (await knex.schema.hasTable('usergroup')) {
    await upsertBy(knex, 'usergroup', { nameen: 'admin' }, { nameth: 'ผู้ดูแลระบบ', use: 'Y' });
    await upsertBy(knex, 'usergroup', { nameen: 'officer' }, { nameth: 'เจ้าหน้าที่', use: 'Y' });
  }

  if (await knex.schema.hasTable('users')) {
    const adminGroup = await knex('usergroup').where({ nameen: 'admin' }).first('id');
    const officerGroup = await knex('usergroup').where({ nameen: 'officer' }).first('id');
    const adminHash = await hashPassword('admin', 'admin1234');
    const officerHash = await hashPassword('officer', 'officer1234');
    const legacyAdmin = await knex('users').where({ username: 'thanawat', email: 'thanawat.kate@gmail.com' }).first();
    if (legacyAdmin && !(await knex('users').where({ username: 'admin' }).first())) {
      await knex('users').where({ id: legacyAdmin.id }).update({
        code: '01', email: 'admin@saccm.local', username: 'admin', password: adminHash,
        name: 'Admin', lastname: 'System', contactnumber: '', refusergroup: adminGroup?.id ?? 1,
        refprefix: null,
      });
    } else {
      await upsertBy(knex, 'users', { username: 'admin' }, {
        code: '01', email: 'admin@saccm.local', password: adminHash,
        name: 'Admin', lastname: 'System', contactnumber: '', refusergroup: adminGroup?.id ?? 1,
        refprefix: null,
      });
    }
    await upsertBy(knex, 'users', { username: 'officer' }, {
      code: '02', email: 'officer@saccm.local', password: officerHash,
      name: 'Officer', lastname: 'User', contactnumber: '', refusergroup: officerGroup?.id ?? 2,
      refprefix: null,
    });
  }

  if (await knex.schema.hasTable('bank')) {
    for (const row of BANKS) {
      await upsertBy(knex, 'bank', { code: row.code }, { ...row, use: 'Y' });
    }
    await knex('bank')
      .whereNotIn('code', BANKS.map((b) => b.code))
      .whereNotExists(function () {
        this.select(1).from('bankaccount').whereRaw('bankaccount.refbank = bank.id');
      })
      .del();
  }

  if (await knex.schema.hasTable('moneytype')) {
    for (const row of MONEY_TYPES) {
      const existing = await knex('moneytype').where({ id: row.id }).first();
      if (existing) {
        await knex('moneytype').where({ id: row.id }).update({ name: row.name, remark: '', sort: row.sort, use: 'Y' });
      } else {
        await knex('moneytype').insert({ id: row.id, name: row.name, remark: '', sort: row.sort, use: 'Y' });
      }
    }
  }

  if (await knex.schema.hasTable('incometype')) {
    for (const row of INCOME_TYPES) {
      await upsertBy(knex, 'incometype', { code: row.code }, { ...row, use: 'Y' });
    }
    await knex('incometype')
      .where('code', 'like', 'OB-%')
      .update({ remark: 'หมวดเงินนอกงบประมาณ (ทะเบียนคุมตามคู่มือการเงิน)', use: 'Y' });
    await knex('incometype')
      .where({ code: 'GUAR-01' })
      .update({ name: 'เงินประกันสัญญา', remark: 'เงินประกันสัญญา', sort: 201, use: 'Y', refmoneygroup: 4, refbankaccount: null });
    await knex('incometype')
      .where({ code: 'WHT-01' })
      .update({ name: 'ภาษีหัก ณ ที่จ่าย (ทะเบียนคุม)', remark: 'ภาษีหัก ณ ที่จ่าย (ทะเบียนคุม)', sort: 202, use: 'Y', refmoneygroup: 3, refbankaccount: null });
  }

  if (await knex.schema.hasTable('expensetype')) {
    for (const row of EXPENSE_TYPES) {
      await upsertBy(knex, 'expensetype', { code: row.code }, { ...row, use: 'Y' });
    }
  }

  if (await knex.schema.hasTable('cash_keeping_limit')) {
    const remarks = [
      ['general', 'small', 'โรงเรียน ≤120 คน — คู่มือ พ.ศ.2544'],
      ['general', 'big', 'โรงเรียน >120 คน — คู่มือ พ.ศ.2544'],
      ['lunch', 'small', 'เงินอุดหนุนโครงการอาหารกลางวัน'],
      ['lunch', 'big', 'เงินอุดหนุนโครงการอาหารกลางวัน'],
      ['kosor', 'small', 'เงิน กสศ.'],
      ['kosor', 'big', 'เงิน กสศ.'],
      ['school_revenue', 'small', 'เงินรายได้สถานศึกษา'],
      ['school_revenue', 'big', 'เงินรายได้สถานศึกษา'],
    ];
    for (const [fund_kind, school_size, remark] of remarks) {
      await knex('cash_keeping_limit').where({ fund_kind, school_size }).update({ remark, use: 'Y' });
    }
  }

  if (await knex.schema.hasTable('budgetsource')) {
    const fy = currentYearBE();
    const hasRefIncomeType = await knex.schema.hasColumn('budgetsource', 'refincometype');
    const hasRefMoneyGroup = await knex.schema.hasColumn('budgetsource', 'refmoneygroup');
    const hasRefBankAccount = await knex.schema.hasColumn('budgetsource', 'refbankaccount');
    async function ensureBudgetSource(code, name, budgetType, refmoneygroup, refincometype = null) {
      const row = {
        name,
        description: '',
        fiscal_year: fy,
        budget_amount: 0,
        used_amount: 0,
        brought_forward_amount: 0,
        budget_type: budgetType,
        use: 'Y',
      };
      if (hasRefMoneyGroup) row.refmoneygroup = refmoneygroup;
      if (hasRefIncomeType) row.refincometype = refincometype;
      if (hasRefBankAccount) row.refbankaccount = null;
      const existing = await knex('budgetsource').where({ code }).first();
      if (existing) await knex('budgetsource').where({ id: existing.id }).update(row);
      else await knex('budgetsource').insert({ code, ...row });
    }
    await ensureBudgetSource('GOV', 'เงินงบประมาณ', 'งปม', 5);
    await ensureBudgetSource('NONGOV', 'เงินนอกงบประมาณ', 'นอกงปม', 2);
    const incomeRows = await knex('incometype').select('id', 'code', 'name').where('code', 'like', 'OB-%').orderBy('sort', 'asc');
    for (const row of incomeRows) {
      await ensureBudgetSource(`NONGOV-${row.code}`, row.name || row.code, 'นอกงปม', 2, row.id);
    }
    const guar = await knex('incometype').where({ code: 'GUAR-01' }).first('id');
    const wht = await knex('incometype').where({ code: 'WHT-01' }).first('id');
    await ensureBudgetSource('DEP-GUAR', 'เงินประกันสัญญา', 'นอกงปม', 4, guar?.id ?? null);
    await ensureBudgetSource('DEP-WHT', 'เงินภาษีหัก ณ ที่จ่าย', 'นอกงปม', 3, wht?.id ?? null);
  }

  if (await knex.schema.hasTable('app_menu')) {
    for (const row of APP_MENU_ROWS) {
      const existing = await knex('app_menu').where({ slug: row.slug }).first();
      const patch = { ...row, is_active: true, last_modified: knex.fn.now() };
      if (existing) await knex('app_menu').where({ id: existing.id }).update(patch);
      else await knex('app_menu').insert(patch);
    }
  }

  if (await knex.schema.hasTable('usergroup_permission')) {
    const groups = await knex('usergroup').select('id', 'nameen');
    for (const group of groups) {
      const name = String(group.nameen || '').toLowerCase();
      const keys = name === 'admin' ? ADMIN_PERMISSIONS : name === 'officer' ? OFFICER_PERMISSIONS : [];
      for (const permission_key of keys) {
        await knex.raw(
          'INSERT IGNORE INTO usergroup_permission (usergroup_id, permission_key) VALUES (?, ?)',
          [group.id, permission_key],
        );
      }
    }
  }
};

exports.down = async function () {
  // Data alignment migration: no rollback to avoid deleting user-edited master data.
};
