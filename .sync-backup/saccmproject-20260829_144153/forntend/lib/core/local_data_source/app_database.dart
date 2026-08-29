import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
export 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/constants/gov_expense_type_codes.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/home/presentation/pages/home_nav_index.dart';

import 'app_menu_seed_data.dart';

class AppDatabase {
  static const String dbName = 'saccm.db';
  static const int dbVersion =
      23; // v23: ensure report materialized/cache tables on upgrade
  static const String _adminGroupNameTh = 'ผู้ดูแลระบบ';
  static const String _officerGroupNameTh = 'เจ้าหน้าที่';
  static const String _adminGroupNameEn = 'admin';
  static const String _officerGroupNameEn = 'officer';
  static const Set<String> _govIncomeTypeCodes = <String>{
    '01',
    '02',
    '03',
    '04',
    '05',
  };
  static final AppDatabase _instance = AppDatabase._internal();

  Database? _database;

  AppDatabase._internal();

  factory AppDatabase() {
    return _instance;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$dbName';

    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _onCreate(db, version);
        await _seedInitialData(db);
      },
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onOpen: (db) async {
        await _seedInitialData(db);
      },
    );
  }

  Future<void> _onDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw StateError(
      'Database downgrade blocked: $oldVersion -> $newVersion. '
      'Backup/restore or run a forward migration instead.',
    );
  }

  /// SHA-256 hash: SHA256(username + password)
  static String _hashPassword(String username, String password) {
    final bytes = utf8.encode('$username$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> _onCreate(Database db, int version) async {
    // Party master — FK สำหรับ income / expense
    await db.execute('''
      CREATE TABLE party (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'both',
        phone TEXT,
        taxid TEXT,
        remark TEXT,
        isactive INTEGER NOT NULL DEFAULT 1,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_party_name ON party(name COLLATE NOCASE)');

    // --- Master ทั้งหมดก่อนตารางลูก (top-down) ---
    await db.execute('''
      CREATE TABLE member (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        email TEXT,
        phone TEXT,
        address TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE money_type (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        detail TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE bank (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        shortname TEXT,
        code TEXT,
        sort INTEGER DEFAULT 0,
        use TEXT DEFAULT 'Y',
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_account (
        id TEXT PRIMARY KEY,
        accountnumber TEXT,
        accountname TEXT,
        sort INTEGER DEFAULT 0,
        use TEXT DEFAULT 'Y',
        refBank TEXT,
        opening_balance REAL NOT NULL DEFAULT 0,
        is_agency_pocket INTEGER NOT NULL DEFAULT 0,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refBank) REFERENCES bank(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cheque_account (
        id TEXT PRIMARY KEY,
        chequeno TEXT,
        chequename TEXT,
        sort INTEGER DEFAULT 0,
        use TEXT DEFAULT 'Y',
        refBank TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refBank) REFERENCES bank(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE money_group (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        remark TEXT,
        sort INTEGER DEFAULT 0,
        use TEXT DEFAULT 'Y',
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE doc_group (
        id TEXT PRIMARY KEY,
        tablename TEXT NOT NULL,
        name TEXT NOT NULL,
        rungroup TEXT NOT NULL,
        docnoformat TEXT NOT NULL,
        runtaxgroup TEXT,
        taxnoformat TEXT,
        use TEXT DEFAULT 'Y',
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_requests (
        id TEXT PRIMARY KEY,
        method TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        payload TEXT,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
        attempts INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        module TEXT NOT NULL,
        action TEXT NOT NULL,
        entityId TEXT NOT NULL,
        payload TEXT,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE prefix (
        id TEXT PRIMARY KEY,
        prefixTh TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE usergroup (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nameth TEXT NOT NULL,
        nameen TEXT NOT NULL,
        use TEXT DEFAULT 'Y',
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE usergroup_permission (
        usergroup_id INTEGER NOT NULL,
        permission_key TEXT NOT NULL,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY(usergroup_id, permission_key),
        FOREIGN KEY(usergroup_id) REFERENCES usergroup(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    // income_type อ้าง bank_account → ต้องอยู่หลัง bank_account
    await db.execute('''
      CREATE TABLE income_type (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        detail TEXT,
        refBankAccount TEXT,
        sort INTEGER NOT NULL DEFAULT 0,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refBankAccount) REFERENCES bank_account(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    // budget_source_* ต้องก่อน income / expense / expense_type (FK)
    await db.execute('''
      CREATE TABLE budget_source_master (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        budget_type TEXT NOT NULL,
        refFundCategory TEXT,
        refmoneygroup TEXT,
        refBankAccount TEXT,
        description TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refBankAccount) REFERENCES bank_account(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refmoneygroup) REFERENCES money_group(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_budget_source_master_ref_fund_category ON budget_source_master(refFundCategory)');

    await db.execute('''
      CREATE TABLE budget_source_budget (
        id TEXT PRIMARY KEY,
        refBudgetSourceMaster TEXT NOT NULL,
        fiscal_year TEXT NOT NULL,
        budget_amount REAL NOT NULL DEFAULT 0,
        brought_forward_amount REAL NOT NULL DEFAULT 0,
        used_amount REAL NOT NULL DEFAULT 0,
        reserved_amount REAL NOT NULL DEFAULT 0,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refBudgetSourceMaster) REFERENCES budget_source_master(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE income_type_budget_source_map (
        id TEXT PRIMARY KEY,
        refIncomeType TEXT NOT NULL,
        refBudgetSourceMaster TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refIncomeType) REFERENCES income_type(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(refBudgetSourceMaster) REFERENCES budget_source_master(id) ON DELETE CASCADE ON UPDATE CASCADE,
        UNIQUE(refIncomeType, refBudgetSourceMaster)
      )
    ''');
    await _createBudgetSourceLookupIndexes(db);
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_income_type_name ON income_type(name COLLATE NOCASE)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_income_type_last_modified ON income_type(lastModified)');

    await db.execute('''
      CREATE TABLE expense_type (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        remark TEXT,
        sort INTEGER DEFAULT 0,
        refDefaultBudgetSource TEXT,
        use TEXT DEFAULT 'Y',
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refDefaultBudgetSource) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE income (
        id TEXT PRIMARY KEY,
        docno TEXT NOT NULL,
        docdate TEXT NOT NULL,
        detail TEXT,
        amount REAL NOT NULL DEFAULT 0,
        remark TEXT,
        bank_reference TEXT,
        refBudgetSource TEXT,
        refParty TEXT,
        partyName TEXT,
        refBankAccount TEXT,
        refMoneyType TEXT,
        doc_status TEXT NOT NULL DEFAULT 'posted',
        money_domain TEXT,
        approved_by TEXT,
        approved_at TEXT,
        posted_at TEXT,
        change_reason TEXT,
        created TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refBudgetSource) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refParty) REFERENCES party(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refMoneyType) REFERENCES money_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refBankAccount) REFERENCES bank_account(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE income_sub (
        id TEXT PRIMARY KEY,
        refIncome TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        refIncomeType TEXT,
        refMoneyType TEXT,
        remark TEXT,
        detail TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refIncome) REFERENCES income(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(refIncomeType) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refMoneyType) REFERENCES money_type(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expense (
        id TEXT PRIMARY KEY,
        docno TEXT NOT NULL,
        docdate TEXT NOT NULL,
        detail TEXT,
        amount REAL NOT NULL DEFAULT 0,
        remark TEXT,
        refBudgetSource TEXT,
        refExpenseReq TEXT,
        refParty TEXT,
        partyName TEXT,
        refBankAccount TEXT,
        docStatus TEXT NOT NULL DEFAULT 'posted',
        moneyDomain TEXT,
        approvedBy TEXT,
        approvedAt TEXT,
        postedAt TEXT,
        changeReason TEXT,
        created TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refBudgetSource) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refExpenseReq) REFERENCES expense_req(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refParty) REFERENCES party(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refBankAccount) REFERENCES bank_account(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_sub (
        id TEXT PRIMARY KEY,
        refExpense TEXT,
        refExpenseType TEXT,
        refFundCategory TEXT,
        refMoneyType TEXT,
        amount REAL NOT NULL DEFAULT 0,
        remark TEXT,
        created TEXT,
        updated TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refExpense) REFERENCES expense(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(refExpenseType) REFERENCES expense_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refMoneyType) REFERENCES money_type(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_req (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        docno TEXT NOT NULL,
        docdate TEXT,
        amount REAL NOT NULL DEFAULT 0,
        detail TEXT,
        remark TEXT,
        refMember TEXT,
        refBudgetSource TEXT,
        approval_status TEXT NOT NULL DEFAULT 'draft',
        reject_reason TEXT,
        member_name TEXT,
        budget_source_name TEXT,
        created TEXT,
        updated TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refMember) REFERENCES member(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_req_sub (
        id TEXT PRIMARY KEY,
        refExpenseReq TEXT,
        refFundCategory TEXT,
        amount REAL NOT NULL DEFAULT 0,
        remark TEXT,
        created TEXT,
        updated TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refExpenseReq) REFERENCES expense_req(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE loan (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        docno TEXT NOT NULL,
        loandate TEXT,
        duedate TEXT,
        amount REAL NOT NULL DEFAULT 0,
        opening_outstanding REAL NOT NULL DEFAULT 0,
        remark TEXT,
        refMember TEXT,
        created TEXT,
        updated TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refMember) REFERENCES member(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE loan_sub (
        id TEXT PRIMARY KEY,
        refLoan TEXT,
        refFundCategory TEXT,
        amount REAL NOT NULL DEFAULT 0,
        remark TEXT,
        created TEXT,
        updated TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refLoan) REFERENCES loan(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE repay_loan (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        docno TEXT NOT NULL,
        duedate TEXT,
        amount REAL NOT NULL DEFAULT 0,
        remark TEXT,
        refLoan TEXT,
        created TEXT,
        updated TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refLoan) REFERENCES loan(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE repay_loan_sub (
        id TEXT PRIMARY KEY,
        refRepayLoan TEXT,
        refFundCategory TEXT,
        amount REAL NOT NULL DEFAULT 0,
        remark TEXT,
        created TEXT,
        updated TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refRepayLoan) REFERENCES repay_loan(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pay_cheque (
        id TEXT PRIMARY KEY,
        chequeamount REAL NOT NULL DEFAULT 0,
        chequeno TEXT,
        remark TEXT,
        cleared_at TEXT,
        refChequeAccount TEXT,
        refExpense TEXT,
        created TEXT,
        updated TEXT,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refChequeAccount) REFERENCES cheque_account(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refExpense) REFERENCES expense(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT,
        email TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        lastname TEXT NOT NULL,
        contactnumber TEXT,
        refusergroup INTEGER,
        refprefix TEXT,
        forcePasswordChange INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        created TEXT DEFAULT CURRENT_TIMESTAMP,
        updated TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(refusergroup) REFERENCES usergroup(id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY(refprefix) REFERENCES prefix(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE approval_cache (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        docno TEXT,
        amount TEXT,
        member_name TEXT,
        budget_source_name TEXT,
        reject_reason TEXT,
        approver_name TEXT,
        updatedAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE report_snapshot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fiscal_year TEXT NOT NULL UNIQUE,
        total_income REAL NOT NULL DEFAULT 0,
        total_expense REAL NOT NULL DEFAULT 0,
        total_loan REAL NOT NULL DEFAULT 0,
        total_repay REAL NOT NULL DEFAULT 0,
        balance REAL NOT NULL DEFAULT 0,
        net_cash_flow REAL NOT NULL DEFAULT 0,
        fetched_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE report_income_by_month (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        month TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        txn_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE,
        UNIQUE(ref_report_snapshot, month)
      )
    ''');
    await db.execute('''
      CREATE TABLE report_expense_by_month (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        month TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        txn_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE,
        UNIQUE(ref_report_snapshot, month)
      )
    ''');
    await db.execute('''
      CREATE TABLE report_budget_source_line (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        server_budget_id TEXT,
        ref_budget_source_budget TEXT,
        code TEXT,
        name TEXT,
        budget_type TEXT,
        fiscal_year TEXT,
        budget_amount REAL NOT NULL DEFAULT 0,
        brought_forward_amount REAL NOT NULL DEFAULT 0,
        used_expense REAL NOT NULL DEFAULT 0,
        received_income REAL NOT NULL DEFAULT 0,
        remaining REAL NOT NULL DEFAULT 0,
        used_percent TEXT,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(ref_budget_source_budget) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE report_trial_balance_line (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        side TEXT NOT NULL,
        type_name TEXT,
        total REAL NOT NULL DEFAULT 0,
        txn_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE report_budget_remaining_line (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        server_budget_id TEXT,
        ref_budget_source_budget TEXT,
        code TEXT,
        name TEXT,
        budget_type TEXT,
        fiscal_year TEXT,
        budget_amount REAL NOT NULL DEFAULT 0,
        brought_forward_amount REAL NOT NULL DEFAULT 0,
        used_amount REAL NOT NULL DEFAULT 0,
        remaining REAL NOT NULL DEFAULT 0,
        used_percent REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(ref_budget_source_budget) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_report_income_month_snap ON report_income_by_month(ref_report_snapshot)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_report_expense_month_snap ON report_expense_by_month(ref_report_snapshot)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_report_budget_src_snap ON report_budget_source_line(ref_report_snapshot)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_report_trial_snap ON report_trial_balance_line(ref_report_snapshot)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_report_budget_rem_snap ON report_budget_remaining_line(ref_report_snapshot)');
    await _createReportDailyAndBankCacheTables(db);

    await db.execute('''
      CREATE TABLE party_audit_scope (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scope_party_id TEXT NOT NULL UNIQUE,
        total_records INTEGER NOT NULL DEFAULT 0,
        total_pages INTEGER NOT NULL DEFAULT 1,
        per_page INTEGER NOT NULL DEFAULT 200,
        fetched_at TEXT NOT NULL,
        FOREIGN KEY(scope_party_id) REFERENCES party(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE party_audit_server_line (
        server_audit_id INTEGER NOT NULL,
        ref_party_audit_scope INTEGER NOT NULL,
        ref_party_record_id TEXT,
        tablename TEXT NOT NULL,
        record_id TEXT,
        action TEXT NOT NULL,
        old_data TEXT,
        new_data TEXT,
        user_id INTEGER,
        user_name TEXT,
        ip_address TEXT,
        created TEXT NOT NULL,
        PRIMARY KEY(ref_party_audit_scope, server_audit_id),
        FOREIGN KEY(ref_party_audit_scope) REFERENCES party_audit_scope(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(ref_party_record_id) REFERENCES party(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_party_audit_line_scope_created ON party_audit_server_line(ref_party_audit_scope, created)');

    await db.execute('''
      CREATE TABLE app_menu (
        id INTEGER PRIMARY KEY,
        parent_id INTEGER,
        slug TEXT NOT NULL UNIQUE,
        name_th TEXT NOT NULL,
        name_en TEXT NOT NULL,
        route_key TEXT,
        required_permission TEXT,
        icon_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        nav_index INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(parent_id) REFERENCES app_menu(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    await _createOffBudgetCategoryTable(db);
    await _createReceiptBookTables(db);
    await _createDepositGuaranteeTable(db);
    await _createAppointmentOrderTables(db);
    await _createCashKeepingLimitTable(db);
    await _createFiscalYearOpeningTable(db);
    await _createFinanceComplianceTables(db);
  }

  Future<void> _createFinanceComplianceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_closing (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        close_date TEXT NOT NULL UNIQUE,
        snapshot_json TEXT NOT NULL,
        closed_by TEXT,
        note TEXT,
        closed_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bank_reconciliation_adjustment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        as_of_date TEXT NOT NULL,
        ref_bankaccount TEXT,
        reason_code TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createOffBudgetCategoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offbudget_category (
        id INTEGER PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _createReceiptBookTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipt_book (
        id TEXT PRIMARY KEY,
        book_no TEXT NOT NULL,
        receipt_type TEXT NOT NULL DEFAULT 'บร.',
        start_no TEXT NOT NULL,
        end_no TEXT NOT NULL,
        fiscal_year TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'available',
        received_at TEXT,
        received_from TEXT,
        remark TEXT,
        created TEXT DEFAULT CURRENT_TIMESTAMP,
        updated TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipt_issue (
        id TEXT PRIMARY KEY,
        ref_book TEXT NOT NULL,
        receipt_no TEXT NOT NULL,
        issued_at TEXT,
        issued_to TEXT,
        amount REAL DEFAULT 0,
        issue_status TEXT NOT NULL DEFAULT 'used',
        remark TEXT,
        ref_income TEXT,
        created TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(ref_book) REFERENCES receipt_book(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_receipt_issue_book ON receipt_issue(ref_book)');
  }

  Future<void> _createDepositGuaranteeTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deposit_guarantee (
        id TEXT PRIMARY KEY,
        docno TEXT NOT NULL,
        docdate TEXT,
        deposit_type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        ref_party TEXT,
        party_name_snapshot TEXT,
        contract_no TEXT,
        detail TEXT,
        due_date TEXT,
        ref_bank_account TEXT,
        status TEXT NOT NULL DEFAULT 'holding',
        settled_at TEXT,
        settled_docno TEXT,
        settled_remark TEXT,
        fiscal_year TEXT,
        ref_income_id TEXT,
        ref_expense_id TEXT,
        income_docno TEXT,
        expense_docno TEXT,
        created TEXT DEFAULT CURRENT_TIMESTAMP,
        updated TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_deposit_status ON deposit_guarantee(status)');
  }

  Future<void> _createAppointmentOrderTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointment_order (
        id TEXT PRIMARY KEY,
        docno TEXT NOT NULL,
        docdate TEXT,
        order_type TEXT NOT NULL,
        subject TEXT NOT NULL,
        content TEXT,
        fiscal_year TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created TEXT DEFAULT CURRENT_TIMESTAMP,
        updated TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointment_order_member (
        id TEXT PRIMARY KEY,
        ref_appointment TEXT NOT NULL,
        member_name TEXT NOT NULL,
        member_position TEXT,
        role_in_order TEXT NOT NULL DEFAULT 'committee',
        sort INTEGER DEFAULT 0,
        created TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(ref_appointment) REFERENCES appointment_order(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');
  }

  /// v7: ยอดยกมาต้นปีงบประมาณ — mirror ของ backend `fiscal_year_opening`
  ///
  /// bucket ∈ {budget, state_revenue, offbudget, general_subsidy,
  ///           school_revenue, withholding_tax, contract_deposit}
  /// pocket ∈ {cash, bank, agency}
  /// ใช้เสริม opening balance ในรายงาน Daily Balance
  Future<void> _createFiscalYearOpeningTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fiscal_year_opening (
        id TEXT PRIMARY KEY,
        fiscal_year TEXT NOT NULL,
        bucket TEXT NOT NULL,
        pocket TEXT NOT NULL,
        opening_amount REAL NOT NULL DEFAULT 0,
        remark TEXT,
        source TEXT NOT NULL DEFAULT 'manual',
        use TEXT NOT NULL DEFAULT 'Y',
        created TEXT DEFAULT CURRENT_TIMESTAMP,
        updated TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(fiscal_year, bucket, pocket)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fiscal_year_opening_year ON fiscal_year_opening(fiscal_year)');
  }

  Future<void> _createCashKeepingLimitTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_keeping_limit (
        id TEXT PRIMARY KEY,
        fiscal_year TEXT NOT NULL,
        fund_kind TEXT NOT NULL DEFAULT 'general',
        school_size TEXT NOT NULL DEFAULT 'small',
        cash_max REAL NOT NULL DEFAULT 0,
        bank_max REAL NOT NULL DEFAULT 0,
        remark TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created TEXT DEFAULT CURRENT_TIMESTAMP,
        updated TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        last_modified TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  /// สคีมา canonical อยู่ใน `_onCreate` — บันไดอัปเกรดเมื่อ [dbVersion] เพิ่ม
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _upgradeToSchemaV2(db);
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await _createReportDailyCashSummaryCacheTable(db);
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await _upgradeIncomeTypeAddSortColumn(db);
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await _upgradeRepayLoanRefToLoanId(db);
    }
    if (oldVersion < 6 && newVersion >= 6) {
      await _upgradeExpenseReqWorkflowColumns(db);
    }
    if (oldVersion < 7 && newVersion >= 7) {
      await _upgradeExpenseReqWorkflowColumns(db);
    }
    if (oldVersion < 8 && newVersion >= 8) {
      await _upgradeDepositGuaranteeLinkColumns(db);
    }
    if (oldVersion < 9 && newVersion >= 9) {
      await _upgradeDepositGuaranteeDocnoColumns(db);
    }
    if (oldVersion < 10 && newVersion >= 10) {
      await _seedDepositIncomeTypes(db);
    }
    if (oldVersion < 11 && newVersion >= 11) {
      await _upgradeAppMenuExpenseReqLinkTree(db);
    }
    if (oldVersion < 12 && newVersion >= 12) {
      await _upgradePayChequeClearedAt(db);
    }
    if (oldVersion < 13 && newVersion >= 13) {
      await _seedRegisterDepositPermissions(db);
    }
    if (oldVersion < 14 && newVersion >= 14) {
      await _createReportOutstandingChequesCacheTable(db);
    }
    if (oldVersion < 15 && newVersion >= 15) {
      await _createFinanceComplianceTables(db);
    }
    if (oldVersion < 16 && newVersion >= 16) {
      await _upgradeCanonicalMasterDataV16(db);
    }
    if (oldVersion < 17 && newVersion >= 17) {
      await _seedPhase1BudgetSourceMasters(db);
    }
    if (oldVersion < 18 && newVersion >= 18) {
      await _createBudgetSourceLookupIndexes(db);
    }
    if (oldVersion < 19 && newVersion >= 19) {
      await _createReceiptBookTables(db);
    }
    if (oldVersion < 20 && newVersion >= 20) {
      await _upgradeExpenseRefExpenseReqColumn(db);
    }
    if (oldVersion < 21 && newVersion >= 21) {
      await _upgradeIncomeBankReferenceColumn(db);
    }
    if (oldVersion < 22 && newVersion >= 22) {
      await _upgradeLoanServerIdColumns(db);
    }
    if (oldVersion < 23 && newVersion >= 23) {
      await _createReportMaterializedTables(db);
      await _createReportDailyAndBankCacheTables(db);
    }
  }

  Future<void> _upgradeLoanServerIdColumns(Database db) async {
    if (!await _tableHasColumn(db, 'loan', 'server_id')) {
      await db.execute('ALTER TABLE loan ADD COLUMN server_id TEXT');
    }
    if (!await _tableHasColumn(db, 'repay_loan', 'server_id')) {
      await db.execute('ALTER TABLE repay_loan ADD COLUMN server_id TEXT');
    }
  }

  Future<void> _upgradeIncomeBankReferenceColumn(Database db) async {
    if (!await _tableHasColumn(db, 'income', 'bank_reference')) {
      await db.execute('ALTER TABLE income ADD COLUMN bank_reference TEXT');
    }
  }

  Future<void> _upgradeExpenseRefExpenseReqColumn(Database db) async {
    if (!await _tableHasColumn(db, 'expense', 'refExpenseReq')) {
      await db.execute('ALTER TABLE expense ADD COLUMN refExpenseReq TEXT');
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expense_ref_expense_req ON expense(refExpenseReq)',
    );
  }

  Future<void> _createBudgetSourceLookupIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budget_source_master_ref_fund_category ON budget_source_master(refFundCategory)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budget_source_budget_master ON budget_source_budget(refBudgetSourceMaster)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_income_type_budget_source_map_income_type ON income_type_budget_source_map(refIncomeType)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_income_type_budget_source_map_master ON income_type_budget_source_map(refBudgetSourceMaster)',
    );
  }

  /// v16: ประเภทเงิน 5 แถว + แก้ชื่อ id 1 ที่เคยผิด + refmoneygroup บน GOV/NONGOV
  Future<void> _upgradeCanonicalMasterDataV16(Database db) async {
    await _seedCanonicalMoneyGroups(db);
    await _seedDepositIncomeTypes(db);
    await db.update(
      'offbudget_category',
      {
        'name': 'เงินบำรุงลูกเสือ-เนตรนารี-ยุวกาชาด',
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'code = ?',
      whereArgs: ['OB-07'],
    );
    await db.update(
      'income_type',
      {
        'name': 'เงินบำรุงลูกเสือ-เนตรนารี-ยุวกาชาด',
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'code = ?',
      whereArgs: ['OB-07'],
    );
    await db.update(
      'budget_source_master',
      {
        'name': 'เงินงบประมาณ',
        'refmoneygroup': '5',
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'code = ?',
      whereArgs: ['GOV'],
    );
    await db.update(
      'budget_source_master',
      {
        'refmoneygroup': '2',
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'code = ?',
      whereArgs: ['NONGOV'],
    );
    await db.insert(
      'money_type',
      {
        'id': 'money_agency',
        'code': 'AGENCY',
        'name': 'เงินฝากส่วนราชการผู้เบิก',
        'detail': '',
        'synced': 0,
        'lastModified': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// ประเภทเงิน 5 รายการ — id/sort ตรง backend seeds07 (ห้ามสลับ id)
  Future<void> _seedCanonicalMoneyGroups(DatabaseExecutor db) async {
    const groups = <Map<String, Object>>[
      {'id': '1', 'name': 'เงินรายได้แผ่นดิน', 'sort': 1},
      {'id': '2', 'name': 'เงินนอกงบประมาณ', 'sort': 3},
      {'id': '3', 'name': 'เงินภาษีหัก ณ ที่จ่าย', 'sort': 4},
      {'id': '4', 'name': 'เงินประกันสัญญา', 'sort': 5},
      {'id': '5', 'name': 'เงินงบประมาณ', 'sort': 2},
    ];
    final ts = DateTime.now().toIso8601String();
    for (final g in groups) {
      await db.insert(
        'money_group',
        {
          ...g,
          'remark': '',
          'use': 'Y',
          'synced': 0,
          'lastModified': ts,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// v17: แหล่งงบรายหมวด OB-01..OB-13 + เงินประกัน/ภาษี สำหรับผูก master data ให้ครบเฟส 1
  Future<void> _seedPhase1BudgetSourceMasters(Database db) async {
    final fiscalYearBuddhist = (DateTime.now().year + 543).toString();
    final now = DateTime.now().toIso8601String();

    Future<void> ensureMasterAndBudget({
      required String masterId,
      required String code,
      required String name,
      required String budgetType,
      required String refmoneygroup,
      String? refFundCategory,
    }) async {
      await db.insert(
        'budget_source_master',
        {
          'id': masterId,
          'code': code,
          'name': name,
          'budget_type': budgetType,
          'refmoneygroup': refmoneygroup,
          'refFundCategory': refFundCategory,
          'description': '',
          'synced': 0,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await db.update(
        'budget_source_master',
        {
          'refmoneygroup': refmoneygroup,
          if (refFundCategory != null) 'refFundCategory': refFundCategory,
          'lastModified': now,
        },
        where: 'id = ?',
        whereArgs: [masterId],
      );

      await db.insert(
        'budget_source_budget',
        {
          'id': 'bs_budget_${code}_$fiscalYearBuddhist',
          'refBudgetSourceMaster': masterId,
          'fiscal_year': fiscalYearBuddhist,
          'budget_amount': 0,
          'brought_forward_amount': 0,
          'used_amount': 0,
          'reserved_amount': 0,
          'synced': 0,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (refFundCategory != null) {
        await db.insert(
          'income_type_budget_source_map',
          {
            'id': 'itbsm_${refFundCategory}_$masterId',
            'refIncomeType': refFundCategory,
            'refBudgetSourceMaster': masterId,
            'synced': 0,
            'lastModified': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    final obRows = await db.query(
      'income_type',
      columns: ['id', 'code', 'name'],
      where: "code LIKE 'OB-%'",
      orderBy: 'sort ASC',
    );
    for (final row in obRows) {
      final incomeTypeId = row['id']?.toString() ?? '';
      final code = row['code']?.toString() ?? '';
      if (incomeTypeId.isEmpty || code.isEmpty) continue;
      await ensureMasterAndBudget(
        masterId: 'bs_master_nongov_${code.toLowerCase()}',
        code: 'NONGOV-$code',
        name: row['name']?.toString() ?? code,
        budgetType: 'นอกงปม',
        refmoneygroup: '2',
        refFundCategory: incomeTypeId,
      );
    }

    await ensureMasterAndBudget(
      masterId: 'bs_master_dep_guar',
      code: 'DEP-GUAR',
      name: 'เงินประกันสัญญา',
      budgetType: 'นอกงปม',
      refmoneygroup: '4',
      refFundCategory: 'income_type_GUAR-01',
    );
    await ensureMasterAndBudget(
      masterId: 'bs_master_dep_wht',
      code: 'DEP-WHT',
      name: 'เงินภาษีหัก ณ ที่จ่าย',
      budgetType: 'นอกงปม',
      refmoneygroup: '3',
      refFundCategory: 'income_type_WHT-01',
    );
  }

  Future<void> _seedRegisterDepositPermissions(Database db) async {
    const adminKeys = [
      'register.deposit.view',
      'register.deposit.create',
      'register.deposit.update',
      'register.deposit.settle',
      'register.deposit.delete',
    ];
    const officerKeys = ['register.deposit.view'];
    final groups = await db.query('usergroup', columns: ['id', 'nameen']);
    for (final g in groups) {
      final gid = g['id'] as int?;
      if (gid == null) continue;
      final name = (g['nameen'] as String? ?? '').toLowerCase();
      final keys = name == 'admin'
          ? adminKeys
          : name == 'officer'
              ? officerKeys
              : <String>[];
      for (final key in keys) {
        await db.insert(
          'usergroup_permission',
          {'usergroup_id': gid, 'permission_key': key},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  Future<void> _upgradePayChequeClearedAt(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(pay_cheque)');
    final names = cols.map((c) => c['name']?.toString()).toSet();
    if (!names.contains('cleared_at')) {
      await db.execute('ALTER TABLE pay_cheque ADD COLUMN cleared_at TEXT');
    }
  }

  /// v11: ย้ายใบขอเบิกเป็นเมนูหลัก + จัดหมวดธุรกรรมรับ-จ่าย
  Future<void> _upgradeAppMenuExpenseReqLinkTree(Database db) async {
    final ts = DateTime.now().toIso8601String();
    await db.update(
      'app_menu',
      {
        'name_th': TransactionUiText.navSectionTransactions,
        'last_modified': ts
      },
      where: 'slug = ?',
      whereArgs: ['section_transactions'],
    );
    await db.update(
      'app_menu',
      {
        'name_th': TransactionUiText.navSectionApprovalExpense,
        'last_modified': ts,
      },
      where: 'slug = ?',
      whereArgs: ['section_approval_reports'],
    );
    await db.update(
      'app_menu',
      {
        'name_th': TransactionUiText.expenseVoucherRecord,
        'sort_order': 2,
        'last_modified': ts,
      },
      where: 'slug = ?',
      whereArgs: ['expense'],
    );
    await db.update(
      'app_menu',
      {'sort_order': 3, 'last_modified': ts},
      where: 'slug = ?',
      whereArgs: ['loan'],
    );
    final existing = await db.query(
      'app_menu',
      where: 'slug = ?',
      whereArgs: ['expense_req'],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(
        'app_menu',
        {
          'id': 13,
          'parent_id': 1,
          'slug': 'expense_req',
          'name_th': TransactionUiText.expenseReqTabLabel,
          'name_en': 'expense_req',
          'route_key': 'expense_req',
          'required_permission': PermissionKey.navExpenseReq,
          'icon_key': 'request_quote_outlined',
          'sort_order': 1,
          'nav_index': HomeNavIndex.expenseReq,
          'is_active': 1,
          'last_modified': ts,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// หมวดรายรับสำหรับทะเบียนเงินประกัน/ภาษีหัก ณ ที่จ่าย (สอดคล้อง backend GUAR-01, WHT-01)
  Future<void> _seedDepositIncomeTypes(Database db) async {
    const rows = [
      ('GUAR-01', 'เงินประกันสัญญา', 201),
      ('WHT-01', 'ภาษีหัก ณ ที่จ่าย (ทะเบียนคุม)', 202),
    ];
    final batch = db.batch();
    for (final (code, name, sort) in rows) {
      batch.insert(
        'income_type',
        {
          'id': 'income_type_$code',
          'code': code,
          'name': name,
          'detail': name,
          'sort': sort,
          'synced': 0,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _upgradeDepositGuaranteeDocnoColumns(Database db) async {
    for (final col in ['income_docno', 'expense_docno']) {
      if (!await _tableHasColumn(db, 'deposit_guarantee', col)) {
        await db.execute('ALTER TABLE deposit_guarantee ADD COLUMN $col TEXT');
      }
    }
  }

  Future<void> _upgradeDepositGuaranteeLinkColumns(Database db) async {
    for (final col in ['ref_income_id', 'ref_expense_id']) {
      if (!await _tableHasColumn(db, 'deposit_guarantee', col)) {
        await db.execute('ALTER TABLE deposit_guarantee ADD COLUMN $col TEXT');
      }
    }
  }

  /// v6: คอลัมน์ workflow ใบขอเบิก (สอดคล้อง MariaDB expensereq)
  Future<void> _upgradeExpenseReqWorkflowColumns(Database db) async {
    const cols = <String, String>{
      'server_id': 'TEXT',
      'docdate': 'TEXT',
      'detail': 'TEXT',
      'refBudgetSource': 'TEXT',
      'approval_status': "TEXT NOT NULL DEFAULT 'draft'",
      'reject_reason': 'TEXT',
      'member_name': 'TEXT',
      'budget_source_name': 'TEXT',
      'expense_recorded': 'INTEGER NOT NULL DEFAULT 0',
    };
    for (final e in cols.entries) {
      if (!await _tableHasColumn(db, 'expense_req', e.key)) {
        await db
            .execute('ALTER TABLE expense_req ADD COLUMN ${e.key} ${e.value}');
      }
    }
    await db.execute(
      "UPDATE expense_req SET approval_status = 'draft' WHERE approval_status IS NULL OR approval_status = ''",
    );
  }

  /// v5: คืนเงินยืมต้องอ้าง loan.id (FK) — ข้อมูลเก่าบางรายการเก็บ docno
  Future<void> _upgradeRepayLoanRefToLoanId(Database db) async {
    await db.execute('''
      UPDATE repay_loan
      SET refLoan = (
        SELECT l.id FROM loan l WHERE l.docno = repay_loan.refLoan LIMIT 1
      )
      WHERE refLoan IS NOT NULL
        AND refLoan NOT IN (SELECT id FROM loan)
        AND EXISTS (SELECT 1 FROM loan l WHERE l.docno = repay_loan.refLoan)
    ''');
  }

  /// v4: คอลัมน์ `sort` สำหรับเรียงหมวด OB ในทะเบียนคุม (register_local_data_source)
  Future<void> _upgradeIncomeTypeAddSortColumn(Database db) async {
    if (!await _tableHasColumn(db, 'income_type', 'sort')) {
      await db.execute(
        'ALTER TABLE income_type ADD COLUMN sort INTEGER NOT NULL DEFAULT 0',
      );
    }
    // OB-01..OB-13 → sort 101..113 ตาม seed offbudget_category
    await db.execute('''
      UPDATE income_type
      SET sort = 100 + CAST(SUBSTR(code, 4, 2) AS INTEGER)
      WHERE code LIKE 'OB-%' AND LENGTH(code) >= 6
    ''');
    final obTable = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='offbudget_category' LIMIT 1",
    );
    if (obTable.isNotEmpty) {
      await db.execute('''
        UPDATE income_type
        SET sort = (
          SELECT oc.sort FROM offbudget_category oc
          WHERE oc.code = income_type.code
          LIMIT 1
        )
        WHERE EXISTS (
          SELECT 1 FROM offbudget_category oc WHERE oc.code = income_type.code
        )
      ''');
    }
  }

  static Future<bool> _tableHasColumn(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    for (final r in rows) {
      if (r['name']?.toString() == column) return true;
    }
    return false;
  }

  static Future<String?> _tableColumnType(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    for (final r in rows) {
      if (r['name']?.toString() == column) {
        return r['type']?.toString();
      }
    }
    return null;
  }

  /// อัปเกรดจากสคีมา v1 (amount TEXT, ไม่มี FK bank/money_group บางจุด, users.refprefix INTEGER)
  /// เป็น v2 แบบ idempotent: รันซ้ำได้เมื่อสคีมาตรงเป้าหมายแล้วจะข้าม
  Future<void> _upgradeToSchemaV2(Database db) async {
    final masters = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='income'",
    );
    if (masters.isEmpty) return;

    final incomeAmountType =
        await _tableColumnType(db, 'income', 'amount') ?? '';
    final needsFinancialMigrate =
        incomeAmountType.toUpperCase().contains('TEXT');

    if (!await _tableHasColumn(db, 'bank_account', 'is_agency_pocket')) {
      await db.execute(
        'ALTER TABLE bank_account ADD COLUMN is_agency_pocket INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!await _tableHasColumn(db, 'budget_source_budget', 'reserved_amount')) {
      await db.execute(
        'ALTER TABLE budget_source_budget ADD COLUMN reserved_amount REAL NOT NULL DEFAULT 0',
      );
    }

    if (needsFinancialMigrate) {
      await db.execute('PRAGMA foreign_keys = OFF');
      try {
        await db.transaction((txn) async {
          Future<void> exec(String sql) => txn.execute(sql);

          const migTables = <String>[
            '_mig_pay_cheque',
            '_mig_expense_sub',
            '_mig_income_sub',
            '_mig_expense',
            '_mig_income',
            '_mig_expense_req_sub',
            '_mig_expense_req',
            '_mig_repay_loan_sub',
            '_mig_repay_loan',
            '_mig_loan_sub',
            '_mig_loan',
            '_mig_expense_type',
            '_mig_itbsm',
            '_mig_budget_source_budget',
            '_mig_budget_source_master',
            '_mig_income_type',
          ];
          for (final t in migTables) {
            await exec('DROP TABLE IF EXISTS $t');
          }

          await exec(
              'CREATE TABLE _mig_pay_cheque AS SELECT * FROM pay_cheque');
          await exec(
              'CREATE TABLE _mig_expense_sub AS SELECT * FROM expense_sub');
          await exec(
              'CREATE TABLE _mig_income_sub AS SELECT * FROM income_sub');
          await exec('CREATE TABLE _mig_expense AS SELECT * FROM expense');
          await exec('CREATE TABLE _mig_income AS SELECT * FROM income');
          await exec(
            'CREATE TABLE _mig_expense_req_sub AS SELECT * FROM expense_req_sub',
          );
          await exec(
              'CREATE TABLE _mig_expense_req AS SELECT * FROM expense_req');
          await exec(
            'CREATE TABLE _mig_repay_loan_sub AS SELECT * FROM repay_loan_sub',
          );
          await exec(
              'CREATE TABLE _mig_repay_loan AS SELECT * FROM repay_loan');
          await exec('CREATE TABLE _mig_loan_sub AS SELECT * FROM loan_sub');
          await exec('CREATE TABLE _mig_loan AS SELECT * FROM loan');
          await exec(
              'CREATE TABLE _mig_expense_type AS SELECT * FROM expense_type');
          await exec(
            'CREATE TABLE _mig_itbsm AS SELECT * FROM income_type_budget_source_map',
          );
          await exec(
            'CREATE TABLE _mig_budget_source_budget AS SELECT * FROM budget_source_budget',
          );
          await exec(
            'CREATE TABLE _mig_budget_source_master AS SELECT * FROM budget_source_master',
          );
          await exec(
              'CREATE TABLE _mig_income_type AS SELECT * FROM income_type');

          await exec('DROP TABLE IF EXISTS pay_cheque');
          await exec('DROP TABLE IF EXISTS expense_sub');
          await exec('DROP TABLE IF EXISTS expense');
          await exec('DROP TABLE IF EXISTS income_sub');
          await exec('DROP TABLE IF EXISTS income');
          await exec('DROP TABLE IF EXISTS expense_req_sub');
          await exec('DROP TABLE IF EXISTS expense_req');
          await exec('DROP TABLE IF EXISTS repay_loan_sub');
          await exec('DROP TABLE IF EXISTS repay_loan');
          await exec('DROP TABLE IF EXISTS loan_sub');
          await exec('DROP TABLE IF EXISTS loan');
          await exec('DROP TABLE IF EXISTS expense_type');
          await exec('DROP TABLE IF EXISTS income_type_budget_source_map');
          await exec('DROP TABLE IF EXISTS budget_source_budget');
          await exec('DROP TABLE IF EXISTS budget_source_master');
          await exec('DROP TABLE IF EXISTS income_type');

          await exec('''
            CREATE TABLE income_type (
              id TEXT PRIMARY KEY,
              code TEXT,
              name TEXT,
              detail TEXT,
              refBankAccount TEXT,
              sort INTEGER NOT NULL DEFAULT 0,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refBankAccount) REFERENCES bank_account(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO income_type (id, code, name, detail, refBankAccount, sort, synced, lastModified)
            SELECT id, code, name, detail, refBankAccount, 0, synced, lastModified FROM _mig_income_type
          ''');

          await exec('''
            CREATE TABLE budget_source_master (
              id TEXT PRIMARY KEY,
              code TEXT NOT NULL,
              name TEXT NOT NULL,
              budget_type TEXT NOT NULL,
              refFundCategory TEXT,
              refmoneygroup TEXT,
              refBankAccount TEXT,
              description TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refBankAccount) REFERENCES bank_account(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refmoneygroup) REFERENCES money_group(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO budget_source_master SELECT * FROM _mig_budget_source_master
          ''');

          await exec('''
            CREATE TABLE budget_source_budget (
              id TEXT PRIMARY KEY,
              refBudgetSourceMaster TEXT NOT NULL,
              fiscal_year TEXT NOT NULL,
              budget_amount REAL NOT NULL DEFAULT 0,
              brought_forward_amount REAL NOT NULL DEFAULT 0,
              used_amount REAL NOT NULL DEFAULT 0,
              reserved_amount REAL NOT NULL DEFAULT 0,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refBudgetSourceMaster) REFERENCES budget_source_master(id) ON DELETE CASCADE ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO budget_source_budget (
              id, refBudgetSourceMaster, fiscal_year, budget_amount,
              brought_forward_amount, used_amount, reserved_amount, synced, lastModified
            )
            SELECT
              id, refBudgetSourceMaster, fiscal_year,
              budget_amount, brought_forward_amount, used_amount,
              COALESCE(reserved_amount, 0), synced, lastModified
            FROM _mig_budget_source_budget
          ''');

          await exec('''
            CREATE TABLE income_type_budget_source_map (
              id TEXT PRIMARY KEY,
              refIncomeType TEXT NOT NULL,
              refBudgetSourceMaster TEXT NOT NULL,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refIncomeType) REFERENCES income_type(id) ON DELETE CASCADE ON UPDATE CASCADE,
              FOREIGN KEY(refBudgetSourceMaster) REFERENCES budget_source_master(id) ON DELETE CASCADE ON UPDATE CASCADE,
              UNIQUE(refIncomeType, refBudgetSourceMaster)
            )
          ''');
          await exec(
            'INSERT INTO income_type_budget_source_map SELECT * FROM _mig_itbsm',
          );

          await exec('''
            CREATE TABLE expense_type (
              id TEXT PRIMARY KEY,
              code TEXT NOT NULL,
              name TEXT NOT NULL,
              remark TEXT,
              sort INTEGER DEFAULT 0,
              refDefaultBudgetSource TEXT,
              use TEXT DEFAULT 'Y',
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refDefaultBudgetSource) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec(
              'INSERT INTO expense_type SELECT * FROM _mig_expense_type');

          await exec('''
            CREATE TABLE loan (
              id TEXT PRIMARY KEY,
              docno TEXT NOT NULL,
              loandate TEXT,
              duedate TEXT,
              amount REAL NOT NULL DEFAULT 0,
              opening_outstanding REAL NOT NULL DEFAULT 0,
              remark TEXT,
              refMember TEXT,
              created TEXT,
              updated TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refMember) REFERENCES member(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO loan SELECT
              id, docno, loandate, duedate,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              opening_outstanding, remark, refMember, created, updated, synced, lastModified
            FROM _mig_loan
          ''');

          await exec('''
            CREATE TABLE loan_sub (
              id TEXT PRIMARY KEY,
              refLoan TEXT,
              refFundCategory TEXT,
              amount REAL NOT NULL DEFAULT 0,
              remark TEXT,
              created TEXT,
              updated TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refLoan) REFERENCES loan(id) ON DELETE CASCADE ON UPDATE CASCADE,
              FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO loan_sub SELECT
              id, refLoan, refFundCategory,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              remark, created, updated, synced, lastModified
            FROM _mig_loan_sub
          ''');

          await exec('''
            CREATE TABLE repay_loan (
              id TEXT PRIMARY KEY,
              docno TEXT NOT NULL,
              duedate TEXT,
              amount REAL NOT NULL DEFAULT 0,
              remark TEXT,
              refLoan TEXT,
              created TEXT,
              updated TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refLoan) REFERENCES loan(id) ON DELETE CASCADE ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO repay_loan SELECT
              id, docno, duedate,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              remark, refLoan, created, updated, synced, lastModified
            FROM _mig_repay_loan
          ''');

          await exec('''
            CREATE TABLE repay_loan_sub (
              id TEXT PRIMARY KEY,
              refRepayLoan TEXT,
              refFundCategory TEXT,
              amount REAL NOT NULL DEFAULT 0,
              remark TEXT,
              created TEXT,
              updated TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refRepayLoan) REFERENCES repay_loan(id) ON DELETE CASCADE ON UPDATE CASCADE,
              FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO repay_loan_sub SELECT
              id, refRepayLoan, refFundCategory,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              remark, created, updated, synced, lastModified
            FROM _mig_repay_loan_sub
          ''');

          await exec('''
            CREATE TABLE expense_req (
              id TEXT PRIMARY KEY,
              docno TEXT NOT NULL,
              amount REAL NOT NULL DEFAULT 0,
              remark TEXT,
              refMember TEXT,
              created TEXT,
              updated TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refMember) REFERENCES member(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO expense_req SELECT
              id, docno,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              remark, refMember, created, updated, synced, lastModified
            FROM _mig_expense_req
          ''');

          await exec('''
            CREATE TABLE expense_req_sub (
              id TEXT PRIMARY KEY,
              refExpenseReq TEXT,
              refFundCategory TEXT,
              amount REAL NOT NULL DEFAULT 0,
              remark TEXT,
              created TEXT,
              updated TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refExpenseReq) REFERENCES expense_req(id) ON DELETE CASCADE ON UPDATE CASCADE,
              FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO expense_req_sub SELECT
              id, refExpenseReq, refFundCategory,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              remark, created, updated, synced, lastModified
            FROM _mig_expense_req_sub
          ''');

          await exec('''
            CREATE TABLE income (
              id TEXT PRIMARY KEY,
              docno TEXT NOT NULL,
              docdate TEXT NOT NULL,
              detail TEXT,
              amount REAL NOT NULL DEFAULT 0,
              remark TEXT,
              refBudgetSource TEXT,
              refParty TEXT,
              partyName TEXT,
              refBankAccount TEXT,
              refMoneyType TEXT,
              doc_status TEXT NOT NULL DEFAULT 'posted',
              money_domain TEXT,
              approved_by TEXT,
              approved_at TEXT,
              posted_at TEXT,
              change_reason TEXT,
              created TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refBudgetSource) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refParty) REFERENCES party(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refMoneyType) REFERENCES money_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refBankAccount) REFERENCES bank_account(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO income SELECT
              id, docno, docdate, detail,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              remark, refBudgetSource, refParty, partyName, refBankAccount, refMoneyType,
              doc_status, money_domain, approved_by, approved_at, posted_at, change_reason,
              created, synced, lastModified
            FROM _mig_income
          ''');

          await exec('''
            CREATE TABLE expense (
              id TEXT PRIMARY KEY,
              docno TEXT NOT NULL,
              docdate TEXT NOT NULL,
              detail TEXT,
              amount REAL NOT NULL DEFAULT 0,
              remark TEXT,
              refBudgetSource TEXT,
              refExpenseReq TEXT,
              refParty TEXT,
              partyName TEXT,
              refBankAccount TEXT,
              docStatus TEXT NOT NULL DEFAULT 'posted',
              moneyDomain TEXT,
              approvedBy TEXT,
              approvedAt TEXT,
              postedAt TEXT,
              changeReason TEXT,
              created TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refBudgetSource) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refExpenseReq) REFERENCES expense_req(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refParty) REFERENCES party(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refBankAccount) REFERENCES bank_account(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO expense SELECT
              id, docno, docdate, detail,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              remark, refBudgetSource, NULL, refParty, partyName, refBankAccount,
              docStatus, moneyDomain, approvedBy, approvedAt, postedAt, changeReason,
              created, synced, lastModified
            FROM _mig_expense
          ''');

          await exec('''
            CREATE TABLE income_sub (
              id TEXT PRIMARY KEY,
              refIncome TEXT NOT NULL,
              amount REAL NOT NULL DEFAULT 0,
              refIncomeType TEXT,
              refMoneyType TEXT,
              remark TEXT,
              detail TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refIncome) REFERENCES income(id) ON DELETE CASCADE ON UPDATE CASCADE,
              FOREIGN KEY(refIncomeType) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refMoneyType) REFERENCES money_type(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO income_sub SELECT
              id, refIncome,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              refIncomeType, refMoneyType, remark, detail, synced, lastModified
            FROM _mig_income_sub
          ''');

          await exec('''
            CREATE TABLE expense_sub (
              id TEXT PRIMARY KEY,
              refExpense TEXT,
              refExpenseType TEXT,
              refFundCategory TEXT,
              refMoneyType TEXT,
              amount REAL NOT NULL DEFAULT 0,
              remark TEXT,
              created TEXT,
              updated TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refExpense) REFERENCES expense(id) ON DELETE CASCADE ON UPDATE CASCADE,
              FOREIGN KEY(refExpenseType) REFERENCES expense_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refFundCategory) REFERENCES income_type(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refMoneyType) REFERENCES money_type(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO expense_sub SELECT
              id, refExpense, refExpenseType, refFundCategory, refMoneyType,
              CASE WHEN amount IS NULL OR TRIM(CAST(amount AS TEXT)) = '' THEN 0 ELSE CAST(amount AS REAL) END,
              remark, created, updated, synced, lastModified
            FROM _mig_expense_sub
          ''');

          await exec('''
            CREATE TABLE pay_cheque (
              id TEXT PRIMARY KEY,
              chequeamount REAL NOT NULL DEFAULT 0,
              chequeno TEXT,
              remark TEXT,
              refChequeAccount TEXT,
              refExpense TEXT,
              created TEXT,
              updated TEXT,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refChequeAccount) REFERENCES cheque_account(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refExpense) REFERENCES expense(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await exec('''
            INSERT INTO pay_cheque SELECT
              id,
              CASE WHEN chequeamount IS NULL OR TRIM(CAST(chequeamount AS TEXT)) = '' THEN 0 ELSE CAST(chequeamount AS REAL) END,
              chequeno, remark, refChequeAccount, refExpense, created, updated, synced, lastModified
            FROM _mig_pay_cheque
          ''');

          await exec('DROP TABLE IF EXISTS _mig_pay_cheque');
          await exec('DROP TABLE IF EXISTS _mig_expense_sub');
          await exec('DROP TABLE IF EXISTS _mig_income_sub');
          await exec('DROP TABLE IF EXISTS _mig_expense');
          await exec('DROP TABLE IF EXISTS _mig_income');
          await exec('DROP TABLE IF EXISTS _mig_expense_req_sub');
          await exec('DROP TABLE IF EXISTS _mig_expense_req');
          await exec('DROP TABLE IF EXISTS _mig_repay_loan_sub');
          await exec('DROP TABLE IF EXISTS _mig_repay_loan');
          await exec('DROP TABLE IF EXISTS _mig_loan_sub');
          await exec('DROP TABLE IF EXISTS _mig_loan');
          await exec('DROP TABLE IF EXISTS _mig_expense_type');
          await exec('DROP TABLE IF EXISTS _mig_itbsm');
          await exec('DROP TABLE IF EXISTS _mig_budget_source_budget');
          await exec('DROP TABLE IF EXISTS _mig_budget_source_master');
          await exec('DROP TABLE IF EXISTS _mig_income_type');

          await exec(
            'CREATE INDEX IF NOT EXISTS idx_budget_source_master_ref_fund_category ON budget_source_master(refFundCategory)',
          );
          await exec(
            'CREATE INDEX IF NOT EXISTS idx_income_type_name ON income_type(name COLLATE NOCASE)',
          );
          await exec(
            'CREATE INDEX IF NOT EXISTS idx_income_type_last_modified ON income_type(lastModified)',
          );
        });
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }

    final refprefixType =
        await _tableColumnType(db, 'users', 'refprefix') ?? '';
    if (refprefixType.toUpperCase().contains('INT')) {
      await db.execute('PRAGMA foreign_keys = OFF');
      try {
        await db.transaction((txn) async {
          await txn.execute('DROP TABLE IF EXISTS _mig_users');
          await txn.execute('CREATE TABLE _mig_users AS SELECT * FROM users');
          await txn.execute('DROP TABLE users');
          await txn.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              code TEXT,
              email TEXT NOT NULL,
              username TEXT NOT NULL UNIQUE,
              password TEXT NOT NULL,
              name TEXT NOT NULL,
              lastname TEXT NOT NULL,
              contactnumber TEXT,
              refusergroup INTEGER,
              refprefix TEXT,
              forcePasswordChange INTEGER DEFAULT 0,
              isActive INTEGER DEFAULT 1,
              created TEXT DEFAULT CURRENT_TIMESTAMP,
              updated TEXT DEFAULT CURRENT_TIMESTAMP,
              synced INTEGER DEFAULT 0,
              lastModified TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY(refusergroup) REFERENCES usergroup(id) ON DELETE SET NULL ON UPDATE CASCADE,
              FOREIGN KEY(refprefix) REFERENCES prefix(id) ON DELETE SET NULL ON UPDATE CASCADE
            )
          ''');
          await txn.execute('''
            INSERT INTO users (
              id, code, email, username, password, name, lastname, contactnumber,
              refusergroup, refprefix, forcePasswordChange, isActive, created, updated, synced, lastModified
            )
            SELECT
              id, code, email, username, password, name, lastname, contactnumber,
              refusergroup,
              CASE WHEN refprefix IS NULL THEN NULL ELSE CAST(refprefix AS TEXT) END,
              forcePasswordChange, isActive, created, updated, synced, lastModified
            FROM _mig_users
          ''');
          await txn.execute('DROP TABLE IF EXISTS _mig_users');
        });
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }
  }

  Future<void> _createReportDailyAndBankCacheTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_daily_balance_cache (
        report_date TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_bank_reconciliation_cache (
        report_date TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');
    await _createReportDailyCashSummaryCacheTable(db);
    await _createReportOutstandingChequesCacheTable(db);
  }

  Future<void> _createReportMaterializedTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_snapshot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fiscal_year TEXT NOT NULL UNIQUE,
        total_income REAL NOT NULL DEFAULT 0,
        total_expense REAL NOT NULL DEFAULT 0,
        total_loan REAL NOT NULL DEFAULT 0,
        total_repay REAL NOT NULL DEFAULT 0,
        balance REAL NOT NULL DEFAULT 0,
        net_cash_flow REAL NOT NULL DEFAULT 0,
        fetched_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_income_by_month (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        month TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        txn_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE,
        UNIQUE(ref_report_snapshot, month)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_expense_by_month (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        month TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        txn_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE,
        UNIQUE(ref_report_snapshot, month)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_budget_source_line (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        server_budget_id TEXT,
        ref_budget_source_budget TEXT,
        code TEXT,
        name TEXT,
        budget_type TEXT,
        fiscal_year TEXT,
        budget_amount REAL NOT NULL DEFAULT 0,
        brought_forward_amount REAL NOT NULL DEFAULT 0,
        used_expense REAL NOT NULL DEFAULT 0,
        received_income REAL NOT NULL DEFAULT 0,
        remaining REAL NOT NULL DEFAULT 0,
        used_percent TEXT,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(ref_budget_source_budget) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_trial_balance_line (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        side TEXT NOT NULL,
        type_name TEXT,
        total REAL NOT NULL DEFAULT 0,
        txn_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_budget_remaining_line (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_report_snapshot INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        server_budget_id TEXT,
        ref_budget_source_budget TEXT,
        code TEXT,
        name TEXT,
        budget_type TEXT,
        fiscal_year TEXT,
        budget_amount REAL NOT NULL DEFAULT 0,
        brought_forward_amount REAL NOT NULL DEFAULT 0,
        used_amount REAL NOT NULL DEFAULT 0,
        remaining REAL NOT NULL DEFAULT 0,
        used_percent REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(ref_report_snapshot) REFERENCES report_snapshot(id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY(ref_budget_source_budget) REFERENCES budget_source_budget(id) ON DELETE SET NULL ON UPDATE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_report_income_month_snap ON report_income_by_month(ref_report_snapshot)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_report_expense_month_snap ON report_expense_by_month(ref_report_snapshot)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_report_budget_src_snap ON report_budget_source_line(ref_report_snapshot)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_report_trial_snap ON report_trial_balance_line(ref_report_snapshot)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_report_budget_rem_snap ON report_budget_remaining_line(ref_report_snapshot)',
    );
  }

  /// แคชรายงานเช็คค้างตัดบัญชี (คีย์ = วันที่อ้างอิง|ปีงบ)
  Future<void> _createReportOutstandingChequesCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_outstanding_cheques_cache (
        cache_key TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');
  }

  /// แคชผลสรุปเงินสดรายวัน (เทียบเคียง report_daily_balance_cache)
  Future<void> _createReportDailyCashSummaryCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_daily_cash_summary_cache (
        report_date TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');
  }

  /// เพิ่ม `expense_type` รหัส 00 เมื่อยังไม่มี (idempotent)
  /// เป็น idempotent — ใช้ INSERT OR IGNORE และตรวจ existing ก่อน
  Future<void> _ensureExpenseType00(Database db) async {
    final existing = await db.query(
      'expense_type',
      columns: ['id'],
      where: 'code = ?',
      whereArgs: ['00'],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'expense_type',
      {
        'id': 'expense_type_00',
        'code': '00',
        'name': 'งบบุคลากร — ค่าจ้างชั่วคราว',
        'remark':
            'ค่าจ้างลูกจ้างชั่วคราวจากเงินรายได้สถานศึกษา (รายการที่ 1 ในรายงานหน้า 33)',
        'sort': 0,
        'use': 'Y',
        'synced': 0,
        'lastModified': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// สะท้อนหมวด OB จาก offbudget_category → income_type เพื่อให้ทะเบียนคุมและ expense_sub อ้าง FK ได้
  Future<void> _mirrorOffBudgetCategoriesToIncomeType(Database db) async {
    final rows = await db.query(
      'offbudget_category',
      where: 'is_active = 1',
      orderBy: 'sort ASC',
    );
    if (rows.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    for (final r in rows) {
      final id = r['id']?.toString() ?? '';
      final code = r['code']?.toString() ?? '';
      if (id.isEmpty || code.isEmpty) continue;
      await db.insert(
        'income_type',
        {
          'id': id,
          'code': code,
          'name': r['name']?.toString() ?? '',
          'detail': 'หมวดเงินนอกงบประมาณ (ทะเบียนคุมตามคู่มือการเงิน)',
          'sort': (r['sort'] as num?)?.toInt() ?? 0,
          'synced': 0,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Seed ค่าเริ่มต้นประเภทรายรับของโรงเรียน สพฐ. (OBEC)
  Future<void> _seedIncomeTypes(Database db) async {
    final existing = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM income_type',
    );
    final count = existing.first['cnt'] as int? ?? 0;
    if (count > 0) return;

    // รายการประเภทรายรับตามระเบียบกระทรวงศึกษาธิการและแนวทาง สพฐ.
    const types = [
      (
        '01',
        'เงินอุดหนุนรายหัว',
        'เงินอุดหนุนค่าใช้จ่ายในการจัดการศึกษาขั้นพื้นฐาน จัดสรรตามจำนวนนักเรียน',
        1
      ),
      (
        '02',
        'เงินอุดหนุนอาหารกลางวัน',
        'เงินอุดหนุนค่าอาหารกลางวันนักเรียน ระดับก่อนประถม–ประถมศึกษา',
        2
      ),
      (
        '03',
        'เงินอุดหนุนอาหารเสริม (นม)',
        'เงินอุดหนุนโครงการอาหารเสริมนมโรงเรียน',
        3
      ),
      (
        '04',
        'เงินอุดหนุนโครงการเรียนฟรี 15 ปี',
        'ค่าเล่าเรียน ค่าอุปกรณ์การเรียน ค่าชุดนักเรียน ค่ากิจกรรมพัฒนาคุณภาพ',
        4
      ),
      (
        '05',
        'เงินอุดหนุนเฉพาะกิจ/โครงการพิเศษ',
        'เงินอุดหนุนจากหน่วยงานต้นสังกัดหรือภายนอกสำหรับโครงการเฉพาะ',
        5
      ),
      (
        '06',
        'เงินบริจาคและทรัพย์สิน',
        'เงินหรือทรัพย์สินที่ได้รับบริจาคจากผู้ปกครอง ชุมชน หรือองค์กรภายนอก',
        6
      ),
      (
        '07',
        'เงินรายได้สถานศึกษา',
        'รายได้จากการให้บริการ ค่าเช่าพื้นที่ ขายสินค้า กิจกรรมหารายได้',
        7
      ),
      (
        '08',
        'เงินสมทบจากองค์กรปกครองส่วนท้องถิ่น',
        'เงินสนับสนุนจาก อบต. อบจ. เทศบาล หรือหน่วยงานท้องถิ่น',
        8
      ),
      (
        '09',
        'เงินกู้ยืมเพื่อการศึกษา (กยศ./กรอ.)',
        'เงินกู้ยืมที่นักเรียน/นักศึกษาได้รับผ่านกองทุน กยศ. หรือ กรอ.',
        9
      ),
      ('10', 'รายรับอื่น', 'รายรับที่ไม่จัดอยู่ในประเภทข้างต้น', 10),
    ];
    final batch = db.batch();
    for (final (code, name, detail, sort) in types) {
      batch.insert(
        'income_type',
        {
          'id': 'income_type_$code',
          'code': code,
          'name': name,
          'detail': detail,
          'sort': sort,
          'synced': 0,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Seed ค่าเริ่มต้นประเภทรายจ่ายตามระเบียบพัสดุ (8 ประเภท)
  Future<void> _seedExpenseTypes(Database db) async {
    final existing = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM expense_type',
    );
    final count = existing.first['cnt'] as int? ?? 0;
    if (count > 0) return;

    // เรียง 9 ประเภทตาม canonical `.cursor/rules/10-saccm-domain-core.mdc` §3
    const types = [
      (
        '00',
        'งบบุคลากร — ค่าจ้างชั่วคราว',
        'ค่าจ้างลูกจ้างชั่วคราวจากเงินรายได้สถานศึกษา (รายการที่ 1 ในรายงานหน้า 33)',
        0
      ),
      ('01', 'ค่าตอบแทน', 'ค่าจ้าง ค่าตอบแทนบุคลากร โบนัส ค่าตอบแทนพิเศษ', 1),
      ('02', 'ค่าใช้สอย', 'ค่าเช่า ค่าเดินทาง ค่าจัดงาน ค่าพิมพ์ ค่าบริการ', 2),
      (
        '03',
        'ค่าวัสดุ',
        'วัสดุสำนักงาน วัสดุการศึกษา วัสดุงานบ้าน อุปกรณ์กีฬา',
        3
      ),
      (
        '04',
        'ค่าสาธารณูปโภค',
        'ค่าน้ำประปา ค่าไฟฟ้า ค่าโทรศัพท์ ค่าอินเทอร์เน็ต',
        4
      ),
      (
        '05',
        'ค่าครุภัณฑ์',
        'คอมพิวเตอร์ เครื่องพิมพ์ เฟอร์นิเจอร์ อุปกรณ์ครุภัณฑ์',
        5
      ),
      (
        '06',
        'ค่าที่ดินและสิ่งก่อสร้าง',
        'ที่ดิน อาคารเรียน ห้องเรียน ซ่อมแซมอาคาร',
        6
      ),
      (
        '07',
        'เงินอุดหนุน',
        'เงินสนับสนุนนักเรียน ทุนการศึกษา เงินช่วยเหลือ',
        7
      ),
      ('08', 'รายจ่ายอื่น', 'รายจ่ายที่ไม่จัดอยู่ในประเภทข้างต้น', 8),
    ];
    final batch = db.batch();
    for (final (code, name, remark, sort) in types) {
      batch.insert(
        'expense_type',
        {
          'id': 'expense_type_$code',
          'code': code,
          'name': name,
          'remark': remark,
          'sort': sort,
          'use': 'Y',
          'synced': 0,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedDefaultCategoryBudgetSourceLinks(Database db) async {
    final fiscalYearBuddhist = (DateTime.now().year + 543).toString();
    final budgetRows = await db.rawQuery('''
      SELECT
        bsm.id AS master_id,
        bb.id AS budget_id,
        bsm.code AS master_code
      FROM budget_source_budget bb
      INNER JOIN budget_source_master bsm
        ON bsm.id = bb.refBudgetSourceMaster
      WHERE bb.fiscal_year = ?
    ''', [fiscalYearBuddhist]);

    String? govBudgetId;
    String? nonGovBudgetId;
    String? govMasterId;
    String? nonGovMasterId;
    for (final row in budgetRows) {
      final code = (row['master_code']?.toString() ?? '').toUpperCase();
      final budgetId = row['budget_id']?.toString() ?? '';
      final masterId = row['master_id']?.toString() ?? '';
      if (budgetId.isEmpty) continue;
      if (code == 'GOV') govBudgetId = budgetId;
      if (code == 'NONGOV') nonGovBudgetId = budgetId;
      if (code == 'GOV' && masterId.isNotEmpty) govMasterId = masterId;
      if (code == 'NONGOV' && masterId.isNotEmpty) nonGovMasterId = masterId;
    }
    if (govBudgetId == null && nonGovBudgetId == null) return;

    final now = DateTime.now().toIso8601String();
    final incomeTypes = await db.query('income_type', columns: ['id', 'code']);
    String? govDefaultIncomeTypeId;
    String? nonGovDefaultIncomeTypeId;
    for (final row in incomeTypes) {
      final incomeTypeId = row['id']?.toString() ?? '';
      final code = row['code']?.toString() ?? '';
      if (incomeTypeId.isEmpty || code.isEmpty) continue;

      final isGov = _govIncomeTypeCodes.contains(code);
      final targetMasterId = isGov ? govMasterId : nonGovMasterId;
      if (targetMasterId == null || targetMasterId.isEmpty) continue;

      await db.insert(
        'income_type_budget_source_map',
        {
          'id': 'itbsm_${incomeTypeId}_$targetMasterId',
          'refIncomeType': incomeTypeId,
          'refBudgetSourceMaster': targetMasterId,
          'synced': 0,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (isGov) {
        govDefaultIncomeTypeId ??= incomeTypeId;
      } else {
        nonGovDefaultIncomeTypeId ??= incomeTypeId;
      }
    }

    if (govDefaultIncomeTypeId != null) {
      await db.update(
        'budget_source_master',
        {
          'refFundCategory': govDefaultIncomeTypeId,
          'synced': 0,
          'lastModified': now,
        },
        where: 'code = ?',
        whereArgs: ['GOV'],
      );
    }
    if (nonGovDefaultIncomeTypeId != null) {
      await db.update(
        'budget_source_master',
        {
          'refFundCategory': nonGovDefaultIncomeTypeId,
          'synced': 0,
          'lastModified': now,
        },
        where: 'code = ?',
        whereArgs: ['NONGOV'],
      );
    }

    final expenseTypes =
        await db.query('expense_type', columns: ['id', 'code']);
    for (final row in expenseTypes) {
      final expenseTypeId = row['id']?.toString() ?? '';
      final code = row['code']?.toString() ?? '';
      if (expenseTypeId.isEmpty || code.isEmpty) continue;
      final useGov = GovExpenseTypeCodes.linkedToGovMaster.contains(code);
      final targetBudgetId = useGov ? govBudgetId : nonGovBudgetId;
      if (targetBudgetId == null || targetBudgetId.isEmpty) continue;
      await db.update(
        'expense_type',
        {
          'refDefaultBudgetSource': targetBudgetId,
          'synced': 0,
          'lastModified': now,
        },
        where: 'id = ?',
        whereArgs: [expenseTypeId],
      );
    }
  }

  Future<void> _seedAppMenuItems(Transaction txn) async {
    for (final row in AppMenuSeedData.sqliteRows()) {
      await txn.insert(
        'app_menu',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// ให้ทุกกลุ่มผู้ใช้ได้สิทธิ์เมนูพื้นฐาน (หลังเพิ่มคีย์ nav.* — idempotent)
  Future<void> _ensureNavPermissionsAllGroups(Transaction txn) async {
    const navKeys = <String>[
      'nav.home',
      'nav.income',
      'nav.expense_req',
      'nav.expense',
      'nav.loan',
      'nav.reports',
      'nav.usage_guide',
      'nav.logout',
      'nav.register',
      'nav.forms',
    ];
    final groups = await txn.query('usergroup', columns: ['id']);
    for (final row in groups) {
      final gid = row['id'];
      if (gid is! int) continue;
      for (final key in navKeys) {
        await txn.insert(
          'usergroup_permission',
          {'usergroup_id': gid, 'permission_key': key},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  /// Insert default usergroups and seed users (admin + officer).
  /// Passwords are stored as SHA-256(username + password).
  Future<void> _seedInitialData(Database db) async {
    await db.transaction((txn) async {
      Future<int> ensureUserGroup({
        required String nameTh,
        required String nameEn,
      }) async {
        final existing = await txn.query(
          'usergroup',
          columns: ['id'],
          where: 'nameen = ?',
          whereArgs: [nameEn],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return existing.first['id'] as int;
        }

        return txn.insert('usergroup', {
          'nameth': nameTh,
          'nameen': nameEn,
          'use': 'Y',
        });
      }

      Future<void> ensurePrefix({
        required String id,
        required String prefixTh,
      }) async {
        final existing = await txn.query(
          'prefix',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty) return;

        await txn.insert(
          'prefix',
          {
            'id': id,
            'prefixTh': prefixTh,
            'synced': 1,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      Future<void> ensureUser({
        required String code,
        required String email,
        required String username,
        required String password,
        required String name,
        required String lastname,
        required int refUserGroup,
        required int forcePasswordChange,
        required int isActive,
      }) async {
        final existing = await txn.query(
          'users',
          columns: ['id'],
          where: 'username = ?',
          whereArgs: [username],
          limit: 1,
        );
        if (existing.isNotEmpty) return;

        await txn.insert('users', {
          'code': code,
          'email': email,
          'username': username,
          'password': _hashPassword(username, password),
          'name': name,
          'lastname': lastname,
          'contactnumber': '',
          'refusergroup': refUserGroup,
          'forcePasswordChange': forcePasswordChange,
          'isActive': isActive,
        });
      }

      Future<void> ensureDocGroup({
        required String tableName,
        required String name,
        required String runGroup,
        required String docNoFormat,
      }) async {
        final existing = await txn.query(
          'doc_group',
          columns: ['id'],
          where: 'tablename = ?',
          whereArgs: [tableName],
          limit: 1,
        );
        if (existing.isNotEmpty) return;
        final id = 'docgroup_$tableName';
        await txn.insert('doc_group', {
          'id': id,
          'tablename': tableName,
          'name': name,
          'rungroup': runGroup,
          'docnoformat': docNoFormat,
          'use': 'Y',
          'synced': 0,
          'lastModified': DateTime.now().toIso8601String(),
        });
      }

      Future<void> ensureBudgetSourceMaster({
        required String id,
        required String code,
        required String name,
        required String budgetType,
        String? refmoneygroup,
      }) async {
        final existing = await txn.query(
          'budget_source_master',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty) return;
        await txn.insert(
          'budget_source_master',
          {
            'id': id,
            'code': code,
            'name': name,
            'budget_type': budgetType,
            'refmoneygroup': refmoneygroup,
            'refFundCategory': null,
            'description': '',
            'synced': 0,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      Future<void> ensureBudgetSourceBudget({
        required String id,
        required String masterId,
        required String fiscalYear,
      }) async {
        final existing = await txn.query(
          'budget_source_budget',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty) return;
        await txn.insert(
          'budget_source_budget',
          {
            'id': id,
            'refBudgetSourceMaster': masterId,
            'fiscal_year': fiscalYear,
            'budget_amount': 0,
            'brought_forward_amount': 0,
            'used_amount': 0,
            'reserved_amount': 0,
            'synced': 0,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      Future<void> ensureMoneyType({
        required String id,
        required String code,
        required String name,
      }) async {
        final existing = await txn.query(
          'money_type',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty) return;
        await txn.insert(
          'money_type',
          {
            'id': id,
            'code': code,
            'name': name,
            'detail': '',
            'synced': 0,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      Future<void> ensureBank({
        required String id,
        required String name,
        required String shortName,
        required String code,
        required int sort,
      }) async {
        final existing = await txn.query(
          'bank',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty) return;
        await txn.insert(
          'bank',
          {
            'id': id,
            'name': name,
            'shortname': shortName,
            'code': code,
            'sort': sort,
            'use': 'Y',
            'synced': 0,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      final adminGroupId = await ensureUserGroup(
        nameTh: _adminGroupNameTh,
        nameEn: _adminGroupNameEn,
      );
      final officerGroupId = await ensureUserGroup(
        nameTh: _officerGroupNameTh,
        nameEn: _officerGroupNameEn,
      );
      final hasAnyPrefix = (await txn.query(
        'prefix',
        columns: ['id'],
        limit: 1,
      ))
          .isNotEmpty;
      if (!hasAnyPrefix) {
        await ensurePrefix(id: '1', prefixTh: 'นาย');
        await ensurePrefix(id: '2', prefixTh: 'นาง');
        await ensurePrefix(id: '3', prefixTh: 'นางสาว');
      }
      await _seedDefaultPermissions(
        txn: txn,
        adminGroupId: adminGroupId,
        officerGroupId: officerGroupId,
      );
      await _seedAppMenuItems(txn);
      await _ensureNavPermissionsAllGroups(txn);
      await ensureDocGroup(
        tableName: 'income',
        name: 'เลขที่เอกสารรับเงิน',
        runGroup: 'INC',
        docNoFormat: '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}',
      );
      await ensureDocGroup(
        tableName: 'loan',
        name: 'เลขที่เอกสารยืมเงิน',
        runGroup: 'LOAN',
        docNoFormat: '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}',
      );
      await ensureDocGroup(
        tableName: 'expense_req',
        name: 'เลขที่ใบขอเบิก',
        runGroup: 'REQ',
        docNoFormat: '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}',
      );
      await ensureDocGroup(
        tableName: 'repay_loan',
        name: 'เลขที่เอกสารคืนเงินยืม',
        runGroup: 'REPAY',
        docNoFormat: '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}',
      );
      await ensureDocGroup(
        tableName: 'receipt_book',
        name: 'รูปแบบเล่มใบเสร็จ',
        runGroup: 'RB',
        docNoFormat: '{RUN3}',
      );
      final fiscalYearBuddhist = (DateTime.now().year + 543).toString();
      await _seedCanonicalMoneyGroups(txn);
      await ensureBudgetSourceMaster(
        id: 'bs_master_gov',
        code: 'GOV',
        name: 'เงินงบประมาณ',
        budgetType: 'งปม',
        refmoneygroup: '5',
      );
      await ensureBudgetSourceMaster(
        id: 'bs_master_nongov',
        code: 'NONGOV',
        name: 'เงินนอกงบประมาณ',
        budgetType: 'นอกงปม',
        refmoneygroup: '2',
      );
      await ensureBudgetSourceBudget(
        id: 'bs_budget_gov_$fiscalYearBuddhist',
        masterId: 'bs_master_gov',
        fiscalYear: fiscalYearBuddhist,
      );
      await ensureBudgetSourceBudget(
        id: 'bs_budget_nongov_$fiscalYearBuddhist',
        masterId: 'bs_master_nongov',
        fiscalYear: fiscalYearBuddhist,
      );
      await ensureMoneyType(
        id: 'money_cash',
        code: 'CASH',
        name: 'เงินสด',
      );
      await ensureMoneyType(
        id: 'money_transfer',
        code: 'TRANSFER',
        name: 'เงินโอน',
      );
      await ensureMoneyType(
        id: 'money_cheque',
        code: 'CHEQUE',
        name: 'เช็ค',
      );
      await ensureMoneyType(
        id: 'money_agency',
        code: 'AGENCY',
        name: 'เงินฝากส่วนราชการผู้เบิก',
      );
      await ensureBank(
        id: 'bank_bbl',
        name: 'ธนาคารกรุงเทพ',
        shortName: 'BBL',
        code: '002',
        sort: 1,
      );
      await ensureBank(
        id: 'bank_ktb',
        name: 'ธนาคารกรุงไทย',
        shortName: 'KTB',
        code: '006',
        sort: 2,
      );
      await ensureBank(
        id: 'bank_bay',
        name: 'ธนาคารกรุงศรีอยุธยา',
        shortName: 'BAY',
        code: '025',
        sort: 3,
      );
      await ensureBank(
        id: 'bank_kbank',
        name: 'ธนาคารกสิกรไทย',
        shortName: 'KBANK',
        code: '004',
        sort: 4,
      );
      await ensureBank(
        id: 'bank_scb',
        name: 'ธนาคารไทยพาณิชย์',
        shortName: 'SCB',
        code: '014',
        sort: 5,
      );
      await ensureBank(
        id: 'bank_ttb',
        name: 'ธนาคารทหารไทยธนชาต',
        shortName: 'TTB',
        code: '011',
        sort: 6,
      );
      await ensureBank(
        id: 'bank_cimbt',
        name: 'ธนาคารซีไอเอ็มบี ไทย',
        shortName: 'CIMBT',
        code: '022',
        sort: 7,
      );
      await ensureBank(
        id: 'bank_uobt',
        name: 'ธนาคารยูโอบี',
        shortName: 'UOB',
        code: '024',
        sort: 8,
      );
      await ensureBank(
        id: 'bank_lhbank',
        name: 'ธนาคารแลนด์ แอนด์ เฮ้าส์',
        shortName: 'LHBANK',
        code: '073',
        sort: 9,
      );
      await ensureBank(
        id: 'bank_icbct',
        name: 'ธนาคารไอซีบีซี (ไทย)',
        shortName: 'ICBC',
        code: '070',
        sort: 10,
      );
      await ensureBank(
        id: 'bank_kkp',
        name: 'ธนาคารเกียรตินาคินภัทร',
        shortName: 'KKP',
        code: '069',
        sort: 11,
      );
      await ensureBank(
        id: 'bank_tisco',
        name: 'ธนาคารทิสโก้',
        shortName: 'TISCO',
        code: '067',
        sort: 12,
      );
      await ensureBank(
        id: 'bank_baac',
        name: 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร',
        shortName: 'BAAC',
        code: '034',
        sort: 13,
      );
      await ensureBank(
        id: 'bank_gsb',
        name: 'ธนาคารออมสิน',
        shortName: 'GSB',
        code: '030',
        sort: 14,
      );
      await ensureBank(
        id: 'bank_ghb',
        name: 'ธนาคารอาคารสงเคราะห์',
        shortName: 'GHB',
        code: '033',
        sort: 15,
      );
      await ensureBank(
        id: 'bank_ibank',
        name: 'ธนาคารอิสลามแห่งประเทศไทย',
        shortName: 'iBank',
        code: '066',
        sort: 16,
      );
      await ensureBank(
        id: 'bank_exim',
        name: 'ธนาคารเพื่อการส่งออกและนำเข้าแห่งประเทศไทย',
        shortName: 'EXIM',
        code: '065',
        sort: 17,
      );

      // Seed 13 หมวดเงินนอกงบประมาณ ตามคู่มือการปฏิบัติงานการเงิน
      const offBudgetCategories = <Map<String, Object?>>[
        {
          'id': 101,
          'code': 'OB-01',
          'name': 'ค่าจัดการเรียนการสอน',
          'sort': 101
        },
        {
          'id': 102,
          'code': 'OB-02',
          'name': 'ปัจจัยพื้นฐานนักเรียนยากจน',
          'sort': 102
        },
        {'id': 103, 'code': 'OB-03', 'name': 'ค่าหนังสือเรียน', 'sort': 103},
        {'id': 104, 'code': 'OB-04', 'name': 'ค่าอุปกรณ์การเรียน', 'sort': 104},
        {
          'id': 105,
          'code': 'OB-05',
          'name': 'ค่าเครื่องแบบนักเรียน',
          'sort': 105
        },
        {
          'id': 106,
          'code': 'OB-06',
          'name': 'ค่ากิจกรรมพัฒนาผู้เรียน',
          'sort': 106
        },
        {
          'id': 107,
          'code': 'OB-07',
          'name': 'เงินบำรุงลูกเสือ-เนตรนารี-ยุวกาชาด',
          'sort': 107
        },
        {
          'id': 108,
          'code': 'OB-08',
          'name': 'ค่าเครื่องแบบลูกเสือ-เนตรนารี',
          'sort': 108
        },
        {
          'id': 109,
          'code': 'OB-09',
          'name': 'เงินอุดหนุนโครงการอาหารกลางวัน',
          'sort': 109
        },
        {
          'id': 110,
          'code': 'OB-10',
          'name': 'เงินดอกผลกองทุนโครงการอาหารกลางวัน',
          'sort': 110
        },
        {
          'id': 111,
          'code': 'OB-11',
          'name': 'เงินกองทุนเพื่อความเสมอภาคทางการศึกษา (กสศ.)',
          'sort': 111
        },
        {
          'id': 112,
          'code': 'OB-12',
          'name': 'ดอกเบี้ยบัญชีเงินอุดหนุนอื่น',
          'sort': 112
        },
        {
          'id': 113,
          'code': 'OB-13',
          'name': 'ดอกเบี้ยบัญชีโครงการอาหารกลางวัน',
          'sort': 113
        },
      ];
      for (final c in offBudgetCategories) {
        await txn.insert(
          'offbudget_category',
          {
            ...c,
            'is_active': 1,
            'last_modified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // Seed default cash keeping limits ตามคู่มือ พ.ศ.2544
      final fyDefault = (DateTime.now().year + 543).toString();
      const keepingLimits = <Map<String, Object?>>[
        {
          'fund_kind': 'general',
          'school_size': 'small',
          'cash_max': 20000.0,
          'bank_max': 30000.0,
          'remark': 'โรงเรียน ≤120 คน — คู่มือ พ.ศ.2544'
        },
        {
          'fund_kind': 'general',
          'school_size': 'big',
          'cash_max': 30000.0,
          'bank_max': 1000000.0,
          'remark': 'โรงเรียน >120 คน — คู่มือ พ.ศ.2544'
        },
        {
          'fund_kind': 'lunch',
          'school_size': 'small',
          'cash_max': 50000.0,
          'bank_max': 200000.0,
          'remark': 'เงินอุดหนุนโครงการอาหารกลางวัน'
        },
        {
          'fund_kind': 'lunch',
          'school_size': 'big',
          'cash_max': 50000.0,
          'bank_max': 200000.0,
          'remark': 'เงินอุดหนุนโครงการอาหารกลางวัน'
        },
        {
          'fund_kind': 'kosor',
          'school_size': 'small',
          'cash_max': 20000.0,
          'bank_max': 30000.0,
          'remark': 'เงิน กสศ.'
        },
        {
          'fund_kind': 'kosor',
          'school_size': 'big',
          'cash_max': 20000.0,
          'bank_max': 30000.0,
          'remark': 'เงิน กสศ.'
        },
        {
          'fund_kind': 'school_revenue',
          'school_size': 'small',
          'cash_max': 20000.0,
          'bank_max': 30000.0,
          'remark': 'เงินรายได้สถานศึกษา'
        },
        {
          'fund_kind': 'school_revenue',
          'school_size': 'big',
          'cash_max': 30000.0,
          'bank_max': 1000000.0,
          'remark': 'เงินรายได้สถานศึกษา'
        },
      ];
      for (final l in keepingLimits) {
        final id = 'ckl_${l['fund_kind']}_${l['school_size']}_$fyDefault';
        final exists = await txn.query('cash_keeping_limit',
            where: 'id = ?', whereArgs: [id], limit: 1);
        if (exists.isNotEmpty) continue;
        await txn.insert('cash_keeping_limit', {
          'id': id,
          'fiscal_year': fyDefault,
          ...l,
          'is_active': 1,
          'last_modified': DateTime.now().toIso8601String(),
        });
      }

      await ensureUser(
        code: '01',
        email: 'admin@saccm.local',
        username: 'admin',
        password: 'admin1234',
        name: 'Admin',
        lastname: 'System',
        refUserGroup: adminGroupId,
        forcePasswordChange: 1,
        isActive: 1,
      );
      await ensureUser(
        code: '02',
        email: 'officer@saccm.local',
        username: 'officer',
        password: 'officer1234',
        name: 'Officer',
        lastname: 'User',
        refUserGroup: officerGroupId,
        forcePasswordChange: 1,
        isActive: 1,
      );
    });

    // Seed expense types (ทำนอก transaction เพราะ batch ของ sqflite ไม่รองรับ nested)
    await _seedExpenseTypes(db);
    // backstop ให้ DB ที่ seed ไปก่อน v3 (มี code '01'..'08') ได้ '00' เพิ่มเสมอ
    await _ensureExpenseType00(db);
    // Seed income types เริ่มต้นของโรงเรียน (OBEC)
    await _seedIncomeTypes(db);
    // ผูกหมวดรายรับ/รายจ่ายกับแหล่งเงินเริ่มต้น (GOV/NONGOV)
    await _seedDefaultCategoryBudgetSourceLinks(db);
    // OB-01..OB-13 ใน income_type สำหรับผูกรายจ่ายกับทะเบียนคุม
    await _mirrorOffBudgetCategoriesToIncomeType(db);
    await _seedDepositIncomeTypes(db);
    await _seedPhase1BudgetSourceMasters(db);
    // หมวด OB เพิ่มหลังรอบแรก — ผูกแหล่งเงิน NONGOV + refDefault รายจ่ายให้ตรงกับ DB (ซ้ำ idempotent)
    await _seedDefaultCategoryBudgetSourceLinks(db);
  }

  Future<void> _seedDefaultPermissions({
    required Transaction txn,
    required int adminGroupId,
    required int officerGroupId,
  }) async {
    const allPermissions = <String>[
      'nav.home',
      'nav.income',
      'nav.expense_req',
      'nav.expense',
      'nav.loan',
      'nav.reports',
      'nav.usage_guide',
      'nav.logout',
      'nav.register',
      'nav.forms',
      'approval.view',
      'approval.manage',
      'approval.approve',
      'approval.reject',
      'budget_source.view',
      'budget_source.create',
      'budget_source.update',
      'budget_source.delete',
      'setting.view',
      'user_admin.view',
      'user_admin.create',
      'user_admin.reset_password',
      'user_admin.update_role',
      'user_admin.toggle_active',
      'user_admin.permission_manage',
      'audit_log.view',
      'forms.docno.manual_edit',
      'setting.doc_group.configure',
      'menu.configure',
      'register.deposit.view',
      'register.deposit.create',
      'register.deposit.update',
      'register.deposit.settle',
      'register.deposit.delete',
    ];
    const officerPermissions = <String>[
      'nav.home',
      'nav.income',
      'nav.expense_req',
      'nav.expense',
      'nav.loan',
      'nav.reports',
      'nav.usage_guide',
      'nav.logout',
      'nav.register',
      'nav.forms',
      'budget_source.view',
      'register.deposit.view',
    ];

    for (final key in allPermissions) {
      await txn.insert(
        'usergroup_permission',
        {'usergroup_id': adminGroupId, 'permission_key': key},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    for (final key in officerPermissions) {
      await txn.insert(
        'usergroup_permission',
        {'usergroup_id': officerGroupId, 'permission_key': key},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Runs a lightweight integrity report for core table relationships.
  /// Returns orphan counts per relation key and FK violation count.
  Future<Map<String, int>> getRelationshipHealthReport() async {
    final db = await database;
    final report = <String, int>{};

    Future<void> countOrphans({
      required String key,
      required String sql,
    }) async {
      final rows = await db.rawQuery(sql);
      final value = rows.isEmpty ? 0 : (rows.first.values.first as int? ?? 0);
      report[key] = value;
    }

    await countOrphans(
      key: 'users.refusergroup',
      sql: '''
        SELECT COUNT(1) AS c
        FROM users u
        LEFT JOIN usergroup g ON g.id = u.refusergroup
        WHERE u.refusergroup IS NOT NULL AND g.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'users.refprefix',
      sql: '''
        SELECT COUNT(1) AS c
        FROM users u
        LEFT JOIN prefix p ON p.id = u.refprefix
        WHERE u.refprefix IS NOT NULL AND p.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'budget_source_master.refFundCategory',
      sql: '''
        SELECT COUNT(1) AS c
        FROM budget_source_master b
        LEFT JOIN income_type i ON i.id = b.refFundCategory
        WHERE b.refFundCategory IS NOT NULL AND i.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'budget_source_master.refmoneygroup',
      sql: '''
        SELECT COUNT(1) AS c
        FROM budget_source_master b
        LEFT JOIN money_group m ON m.id = b.refmoneygroup
        WHERE b.refmoneygroup IS NOT NULL AND m.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'budget_source_master.refBankAccount',
      sql: '''
        SELECT COUNT(1) AS c
        FROM budget_source_master b
        LEFT JOIN bank_account a ON a.id = b.refBankAccount
        WHERE b.refBankAccount IS NOT NULL AND a.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'income_type.refBankAccount',
      sql: '''
        SELECT COUNT(1) AS c
        FROM income_type t
        LEFT JOIN bank_account a ON a.id = t.refBankAccount
        WHERE t.refBankAccount IS NOT NULL AND a.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'income.refBankAccount',
      sql: '''
        SELECT COUNT(1) AS c
        FROM income i
        LEFT JOIN bank_account a ON a.id = i.refBankAccount
        WHERE i.refBankAccount IS NOT NULL AND a.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'income.refBudgetSource',
      sql: '''
        SELECT COUNT(1) AS c
        FROM income i
        LEFT JOIN budget_source_budget b ON b.id = i.refBudgetSource
        WHERE i.refBudgetSource IS NOT NULL AND b.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'expense.refBudgetSource',
      sql: '''
        SELECT COUNT(1) AS c
        FROM expense e
        LEFT JOIN budget_source_budget b ON b.id = e.refBudgetSource
        WHERE e.refBudgetSource IS NOT NULL AND b.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'expense.refBankAccount',
      sql: '''
        SELECT COUNT(1) AS c
        FROM expense e
        LEFT JOIN bank_account a ON a.id = e.refBankAccount
        WHERE e.refBankAccount IS NOT NULL AND a.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'expense_sub.refExpense',
      sql: '''
        SELECT COUNT(1) AS c
        FROM expense_sub s
        LEFT JOIN expense e ON e.id = s.refExpense
        WHERE s.refExpense IS NOT NULL AND e.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'expense_sub.refFundCategory',
      sql: '''
        SELECT COUNT(1) AS c
        FROM expense_sub s
        LEFT JOIN income_type i ON i.id = s.refFundCategory
        WHERE s.refFundCategory IS NOT NULL AND i.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'expense_req.refMember',
      sql: '''
        SELECT COUNT(1) AS c
        FROM expense_req r
        LEFT JOIN member m ON m.id = r.refMember
        WHERE r.refMember IS NOT NULL AND m.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'expense_req_sub.refExpenseReq',
      sql: '''
        SELECT COUNT(1) AS c
        FROM expense_req_sub s
        LEFT JOIN expense_req r ON r.id = s.refExpenseReq
        WHERE s.refExpenseReq IS NOT NULL AND r.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'expense_req_sub.refFundCategory',
      sql: '''
        SELECT COUNT(1) AS c
        FROM expense_req_sub s
        LEFT JOIN income_type i ON i.id = s.refFundCategory
        WHERE s.refFundCategory IS NOT NULL AND i.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'loan.refMember',
      sql: '''
        SELECT COUNT(1) AS c
        FROM loan l
        LEFT JOIN member m ON m.id = l.refMember
        WHERE l.refMember IS NOT NULL AND m.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'loan_sub.refLoan',
      sql: '''
        SELECT COUNT(1) AS c
        FROM loan_sub s
        LEFT JOIN loan l ON l.id = s.refLoan
        WHERE s.refLoan IS NOT NULL AND l.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'loan_sub.refFundCategory',
      sql: '''
        SELECT COUNT(1) AS c
        FROM loan_sub s
        LEFT JOIN income_type i ON i.id = s.refFundCategory
        WHERE s.refFundCategory IS NOT NULL AND i.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'repay_loan.refLoan',
      sql: '''
        SELECT COUNT(1) AS c
        FROM repay_loan r
        LEFT JOIN loan l ON l.id = r.refLoan
        WHERE r.refLoan IS NOT NULL AND l.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'repay_loan_sub.refRepayLoan',
      sql: '''
        SELECT COUNT(1) AS c
        FROM repay_loan_sub s
        LEFT JOIN repay_loan r ON r.id = s.refRepayLoan
        WHERE s.refRepayLoan IS NOT NULL AND r.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'repay_loan_sub.refFundCategory',
      sql: '''
        SELECT COUNT(1) AS c
        FROM repay_loan_sub s
        LEFT JOIN income_type i ON i.id = s.refFundCategory
        WHERE s.refFundCategory IS NOT NULL AND i.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'cheque_account.refBank',
      sql: '''
        SELECT COUNT(1) AS c
        FROM cheque_account c
        LEFT JOIN bank b ON b.id = c.refBank
        WHERE c.refBank IS NOT NULL AND b.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'pay_cheque.refChequeAccount',
      sql: '''
        SELECT COUNT(1) AS c
        FROM pay_cheque p
        LEFT JOIN cheque_account c ON c.id = p.refChequeAccount
        WHERE p.refChequeAccount IS NOT NULL AND c.id IS NULL
      ''',
    );
    await countOrphans(
      key: 'pay_cheque.refExpense',
      sql: '''
        SELECT COUNT(1) AS c
        FROM pay_cheque p
        LEFT JOIN expense e ON e.id = p.refExpense
        WHERE p.refExpense IS NOT NULL AND e.id IS NULL
      ''',
    );

    final fkViolations = await db.rawQuery('PRAGMA foreign_key_check');
    report['foreign_key_check.violations'] = fkViolations.length;
    return report;
  }

  /// จำนวนแถวต่อตาราง — คีย์ = ชื่อตาราง SQLite และลำดับต้องตรงกับ
  /// `SYNC_DIGEST_TABLES` ใน `backend/src/constants/sync_digest_tables.js`
  static const Map<String, String> _syncDigestLocalCountSql = {
    'income': 'SELECT COUNT(*) AS c FROM income',
    'expense': 'SELECT COUNT(*) AS c FROM expense',
    'party': 'SELECT COUNT(*) AS c FROM party',
    'budget_source_budget': 'SELECT COUNT(*) AS c FROM budget_source_budget',
    'users': 'SELECT COUNT(*) AS c FROM users',
    'moneytype': 'SELECT COUNT(*) AS c FROM money_type',
    'incometype': 'SELECT COUNT(*) AS c FROM income_type',
    'bank': 'SELECT COUNT(*) AS c FROM bank',
    'bankaccount': 'SELECT COUNT(*) AS c FROM bank_account',
    'chequeaccount': 'SELECT COUNT(*) AS c FROM cheque_account',
    'pay_cheque': 'SELECT COUNT(*) AS c FROM pay_cheque',
    'member': 'SELECT COUNT(*) AS c FROM member',
    'prefix': 'SELECT COUNT(*) AS c FROM prefix',
    'usergroup': 'SELECT COUNT(*) AS c FROM usergroup',
    'docgroup': 'SELECT COUNT(*) AS c FROM doc_group',
    'moneygroup': 'SELECT COUNT(*) AS c FROM money_group',
    'incomesub': 'SELECT COUNT(*) AS c FROM income_sub',
    'expensesub': 'SELECT COUNT(*) AS c FROM expense_sub',
    'loan': 'SELECT COUNT(*) AS c FROM loan',
    'loansub': 'SELECT COUNT(*) AS c FROM loan_sub',
    'repayloan': 'SELECT COUNT(*) AS c FROM repay_loan',
    'repayloansub': 'SELECT COUNT(*) AS c FROM repay_loan_sub',
    'expensereq': 'SELECT COUNT(*) AS c FROM expense_req',
    'expensereqsub': 'SELECT COUNT(*) AS c FROM expense_req_sub',
    'deposit_guarantee': 'SELECT COUNT(*) AS c FROM deposit_guarantee',
  };

  /// นับแถวสำหรับเทียบกับ [SyncDigestRemoteDataSource]
  Future<Map<String, int>> getSyncDigestCounts() async {
    final db = await database;
    final out = <String, int>{};
    for (final e in _syncDigestLocalCountSql.entries) {
      try {
        final rows = await db.rawQuery(e.value);
        final v = rows.isEmpty ? 0 : rows.first.values.first;
        final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
        out[e.key] = n;
      } catch (_) {
        out[e.key] = -1;
      }
    }
    return out;
  }

  /// สำเนา DB แบบสอดคล้อง (SQLite VACUUM INTO) โดยไม่ต้องปิดการเชื่อมต่อทั้งหมด
  Future<void> vacuumIntoPath(String destinationPath) async {
    if (kIsWeb) {
      throw UnsupportedError('การสำรองแบบไฟล์ยังไม่รองรับบนเว็บ');
    }
    final db = await database;
    final normalized =
        destinationPath.replaceAll('\\', '/').replaceAll("'", "''");
    await db.execute("VACUUM INTO '$normalized'");
  }

  /// ลบ `saccm.db` แล้วสร้างใหม่พร้อม seed ตั้งต้น (หน้ารีเซทฐานข้อมูล)
  Future<void> resetDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('รีเซทฐานข้อมูลยังไม่รองรับบนเว็บ');
    }
    await close();
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$dbName';
    await deleteDatabase(path);
    _database = await _initDatabase();
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
