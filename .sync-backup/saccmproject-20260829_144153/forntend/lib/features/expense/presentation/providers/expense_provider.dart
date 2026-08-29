import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/local_data_source/cheque_account_local_data_source.dart';
import 'package:saccm/core/local_data_source/expense_local_data_source.dart';
import 'package:saccm/core/services/expense_sync_warning_service.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/expense/data/repositories/expense_repository_offline.dart';
import 'package:saccm/features/expense/domain/models/expense_entry_prefill.dart';
import 'package:saccm/features/expense/domain/rules/expense_budget_source_rule.dart';
import 'package:saccm/features/income/data/repositories/income_repository_offline.dart'
    as income_offline;
import 'package:saccm/features/income/domain/usecases/get_doc_no.dart';

class ExpenseProvider extends ChangeNotifier {
  static String _lastUsedBudgetSourceCode = '';

  bool isLoading = false;
  String? error;
  String? syncWarning;
  bool _disposed = false;

  // ─── Budget source state ──────────────────────────────────────────
  /// รายการแหล่งเงินทั้งหมด (ก่อนกรองตามประเภทรายจ่าย)
  List<List<String>> _allBudgetSourceRows = const [];
  List<List<String>> budgetSource = const [];
  String budgetSourceCode = '';
  List<String> partyOptions = const [];
  // ─── Expense type state ──────────────────────────────────────────
  List<List<String>> expenseTypes = const [];
  String expenseTypeCode = '';
  // ─── รูปแบบการจ่าย + หมวดทะเบียนคุม (นอกงบฯ) ─────────────────────
  /// แต่ละแถว = [id, name, code]
  List<List<String>> moneyTypes = const [];
  String moneyTypeCode = '';
  List<List<String>> offBudgetFundCategories = const [];
  String fundCategoryId = '';

  // ─── จ่ายโดยเช็ค (pay_cheque) ────────────────────────────────────
  /// แต่ละแถว = [id, label]
  List<List<String>> chequeAccounts = const [];
  String chequeAccountId = '';

  // ─── วงเงินเก็บรักษา (cash_keeping_limit) ─────────────────────────
  /// แมป fund_kind → {cash_max, bank_max} สำหรับ school_size ปัจจุบัน
  Map<String, Map<String, double>> cashKeepingLimits = const {};
  late final ExpenseRepository _repository;
  final BudgetSourceLocalDataSource _budgetSourceDs =
      BudgetSourceLocalDataSource();
  final ExpenseLocalDataSource _localDataSource = ExpenseLocalDataSource();

  ExpenseProvider({ExpenseRepository? repository}) {
    _repository =
        repository ?? ServiceLocator.instance.get<ExpenseRepository>();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Stage 1: คืน local ทันที
  /// Stage 2: background pull เมื่อ remote data source พร้อม
  Future<void> loadExpenseList(Function(List<dynamic>) onDataLoaded) async {
    isLoading = true;
    error = null;
    syncWarning = null;
    ExpenseSyncWarningService.instance.clear();
    _safeNotify();

    try {
      // Stage 1: Local data ทันที
      final items = await _repository.getExpenseList();
      if (!_disposed) onDataLoaded(_toDataList(items));
    } catch (e) {
      error = toUserErrorMessage(
        e,
        fallback: TransactionUiText.genericTryAgain,
      );
    } finally {
      isLoading = false;
      _safeNotify();
    }

    // Stage 2: Background pull (no-op until remote source is implemented)
    unawaited(
      _repository.backgroundPull().then((synced) async {
        if (_disposed) return;
        syncWarning =
            synced ? null : TransactionUiText.expenseSyncServerUnavailable;
        ExpenseSyncWarningService.instance.setWarning(syncWarning);
        final refreshed = await _repository.getExpenseList();
        if (!_disposed) onDataLoaded(_toDataList(refreshed));
        _safeNotify();
      }).catchError((_) {}),
    );
  }

  Future<bool> saveExpense({
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    required String partyName,
    required String refMember,
    required List<Map<String, dynamic>> subData,
    List<Map<String, dynamic>> payCheque = const [],
    String bankAmount = '0',
    String? moneyDomain,
    String? refExpenseReq,
    String? refExpenseReqServerId,
    String docStatus = 'posted',
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();

    try {
      await _repository.createExpense(
        token: token,
        docno: docno,
        docdate: docdate,
        amount: amount,
        detail: detail,
        remark: remark,
        partyName: partyName,
        refMember: refMember,
        refBudgetSource: budgetSourceCode.isEmpty ? null : budgetSourceCode,
        refExpenseReq: refExpenseReq,
        subData: subData,
        payCheque: payCheque,
        bankAmount: bankAmount,
        moneyDomain: moneyDomain,
        refExpenseReqServerId: refExpenseReqServerId,
        lineRefMoneyTypeFallback:
            moneyTypeCode.trim().isEmpty ? null : moneyTypeCode,
        lineRefIncomeTypeFallback:
            fundCategoryId.trim().isEmpty ? null : fundCategoryId,
        docStatus: docStatus,
      );
      isLoading = false;
      _safeNotify();
      return true;
    } catch (e) {
      error = toUserErrorMessage(
        e,
        fallback: TransactionUiText.createFailed,
      );
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<bool> updateExpense({
    required String localId,
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    required String partyName,
    required String refMember,
    required List<Map<String, dynamic>> subData,
    List<Map<String, dynamic>> payCheque = const [],
    String bankAmount = '0',
    String? moneyDomain,
    String? refExpenseReq,
    String? refExpenseReqServerId,
    String? changeReason,
    String? docStatus,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();

    try {
      await _repository.updateExpense(
        localId: localId,
        token: token,
        docno: docno,
        docdate: docdate,
        amount: amount,
        detail: detail,
        remark: remark,
        partyName: partyName,
        refMember: refMember,
        refBudgetSource: budgetSourceCode.isEmpty ? null : budgetSourceCode,
        refExpenseReq: refExpenseReq,
        subData: subData,
        payCheque: payCheque,
        bankAmount: bankAmount,
        moneyDomain: moneyDomain,
        refExpenseReqServerId: refExpenseReqServerId,
        changeReason: changeReason,
        lineRefMoneyTypeFallback:
            moneyTypeCode.trim().isEmpty ? null : moneyTypeCode,
        lineRefIncomeTypeFallback:
            fundCategoryId.trim().isEmpty ? null : fundCategoryId,
        docStatus: docStatus,
      );
      isLoading = false;
      _safeNotify();
      return true;
    } catch (e) {
      error = toUserErrorMessage(
        e,
        fallback: TransactionUiText.updateFailed,
      );
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<String?> upsertAutoDraft({
    String? localId,
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    required String partyName,
    required String refMember,
    required List<Map<String, dynamic>> subData,
    List<Map<String, dynamic>> payCheque = const [],
    String bankAmount = '0',
    String? moneyDomain,
    String? refExpenseReq,
    String? refExpenseReqServerId,
  }) async {
    try {
      final id = await _repository.upsertDraftExpense(
        localId: localId,
        token: token,
        docno: docno,
        docdate: docdate,
        amount: amount,
        detail: detail,
        remark: remark,
        partyName: partyName,
        refMember: refMember,
        refBudgetSource: budgetSourceCode.isEmpty ? null : budgetSourceCode,
        refExpenseReq: refExpenseReq,
        subData: subData,
        payCheque: payCheque,
        bankAmount: bankAmount,
        moneyDomain: moneyDomain,
        refExpenseReqServerId: refExpenseReqServerId,
        lineRefMoneyTypeFallback:
            moneyTypeCode.trim().isEmpty ? null : moneyTypeCode,
        lineRefIncomeTypeFallback:
            fundCategoryId.trim().isEmpty ? null : fundCategoryId,
      );
      error = null;
      return id;
    } catch (e) {
      error = toUserErrorMessage(
        e,
        fallback: TransactionUiText.updateFailed,
      );
      return null;
    }
  }

  Future<bool> deleteExpense({
    required String localId,
    required String token,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.deleteExpense(localId: localId, token: token);
      isLoading = false;
      _safeNotify();
      return true;
    } catch (e) {
      error = toUserErrorMessage(
        e,
        fallback: TransactionUiText.cannotDelete,
      );
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  ExpenseModel? getExpenseById(String id) => null;

  Future<List<Map<String, dynamic>>> loadExpenseSubs(String expenseId) =>
      _repository.getExpenseSubs(expenseId);

  Future<Map<String, dynamic>?> loadPayChequeRow(String expenseId) =>
      _repository.getPayChequeForExpense(expenseId);

  Future<List<Map<String, dynamic>>> loadPayChequeRows(String expenseId) =>
      _repository.getPayChequesForExpense(expenseId);

  Future<bool> get isConnected => _repository.isConnected;

  // ─── Budget source helpers ─────────────────────────────────────────

  Future<void> loadBudgetSources() async {
    try {
      await _budgetSourceDs.init();
      final items = await _budgetSourceDs.getAllBudgetSources();
      _allBudgetSourceRows =
          items.map((e) => [e.id, '${e.code} - ${e.name}']).toList();
    } catch (_) {
      _allBudgetSourceRows = const [];
    }
    _rebuildFilteredBudgetSources();
  }

  /// แสดงเฉพาะแหล่งเงินที่สอดคล้องกับประเภทรายจ่ายที่เลือก
  /// เพื่อกันการปนงบแผ่นดิน/นอกงบประมาณผิดทะเบียนตั้งแต่หน้าฟอร์ม
  void _rebuildFilteredBudgetSources() {
    if (expenseTypeCode.isEmpty) {
      budgetSource = const [];
    } else {
      budgetSource = ExpenseBudgetSourceRule.filterBudgetSources(
        allSources: _allBudgetSourceRows,
        expenseTypeId: expenseTypeCode,
        expenseTypeRows: expenseTypes,
      );
    }
    if (budgetSourceCode.isNotEmpty &&
        !budgetSource.any((r) => r.isNotEmpty && r[0] == budgetSourceCode)) {
      budgetSourceCode = '';
      fundCategoryId = '';
    }
    _safeNotify();
  }

  void addBudgetSourceCode(String val) {
    budgetSourceCode = val;
    if (budgetSourceCode.isNotEmpty &&
        !budgetSource.any((r) => r.isNotEmpty && r[0] == budgetSourceCode)) {
      budgetSourceCode = '';
      fundCategoryId = '';
    }
    if (budgetSourceCode.isNotEmpty) {
      _lastUsedBudgetSourceCode = budgetSourceCode;
    }
    _safeNotify();
  }

  String get lastUsedBudgetSourceCode => _lastUsedBudgetSourceCode;

  void addMoneyTypeCode(String val) {
    moneyTypeCode = val;
    _safeNotify();
  }

  void addFundCategoryId(String val) {
    fundCategoryId = val;
    _safeNotify();
  }

  /// เติมค่าจากใบขอเบิกที่อนุมัติแล้ว (เรียกหลัง load lookups)
  void applyEntryPrefill(ExpenseEntryPrefill prefill) {
    if (prefill.budgetSourceRowId != null &&
        prefill.budgetSourceRowId!.isNotEmpty) {
      for (final et in expenseTypes) {
        if (et.isEmpty) continue;
        final filtered = ExpenseBudgetSourceRule.filterBudgetSources(
          allSources: _allBudgetSourceRows,
          expenseTypeId: et[0],
          expenseTypeRows: expenseTypes,
        );
        if (filtered
            .any((r) => r.isNotEmpty && r[0] == prefill.budgetSourceRowId)) {
          expenseTypeCode = et[0];
          break;
        }
      }
    }
    if (expenseTypeCode.isEmpty && expenseTypes.isNotEmpty) {
      expenseTypeCode = expenseTypes.first[0];
    }
    _rebuildFilteredBudgetSources();
    if (prefill.budgetSourceRowId != null &&
        prefill.budgetSourceRowId!.isNotEmpty) {
      addBudgetSourceCode(prefill.budgetSourceRowId!);
    }
    if (prefill.fundCategoryId != null && prefill.fundCategoryId!.isNotEmpty) {
      addFundCategoryId(prefill.fundCategoryId!);
    }
    for (final mt in moneyTypes) {
      if (mt.isEmpty) continue;
      final name = mt.length > 1 ? mt[1] : '';
      final code = mt.length > 2 ? mt[2] : '';
      final n = name.toLowerCase();
      if (n.contains('เงินสด') ||
          n.contains('cash') ||
          code.toLowerCase() == 'cash') {
        moneyTypeCode = mt[0];
        break;
      }
    }
    if (moneyTypeCode.isEmpty && moneyTypes.isNotEmpty) {
      moneyTypeCode = moneyTypes.first[0];
    }
    _safeNotify();
  }

  /// โหลดประเภทรายจ่ายจาก SQLite local (expense_type)
  Future<void> loadExpenseTypes() async {
    try {
      await _localDataSource.init();
      expenseTypes = await _localDataSource.getAllExpenseTypes();
    } catch (_) {
      expenseTypes = const [];
    }
    _rebuildFilteredBudgetSources();
  }

  Future<void> loadMoneyTypes() async {
    try {
      await _localDataSource.init();
      moneyTypes = await _localDataSource.getAllMoneyTypes();
    } catch (_) {
      moneyTypes = const [];
    }
    _safeNotify();
  }

  Future<void> loadOffBudgetFundCategories() async {
    try {
      await _localDataSource.init();
      offBudgetFundCategories =
          await _localDataSource.getOffBudgetFundCategories();
    } catch (_) {
      offBudgetFundCategories = const [];
    }
    _safeNotify();
  }

  Future<void> loadChequeAccounts() async {
    try {
      final ds = ChequeAccountLocalDataSource();
      await ds.ensureInitialized();
      chequeAccounts = await ds.getActiveForDropdown();
    } catch (_) {
      chequeAccounts = const [];
    }
    _safeNotify();
  }

  void addChequeAccountId(String val) {
    chequeAccountId = val;
    _safeNotify();
  }

  /// Load วงเงินเก็บรักษาสำหรับ fund_kind ทุกประเภท ตาม school_size ปัจจุบัน
  /// (frontend ยังไม่เก็บจำนวนนักเรียน — ใช้ 'small' เป็น default ที่ปลอดภัยที่สุด)
  Future<void> loadCashKeepingLimits({String schoolSize = 'small'}) async {
    try {
      await _localDataSource.init();
      final out = <String, Map<String, double>>{};
      for (final kind in const [
        'lunch',
        'kosor',
        'school_revenue',
        'general'
      ]) {
        final v = await _localDataSource.getCashKeepingLimit(
          fundKind: kind,
          schoolSize: schoolSize,
        );
        if (v != null) out[kind] = v;
      }
      cashKeepingLimits = out;
    } catch (_) {
      cashKeepingLimits = const {};
    }
    _safeNotify();
  }

  void addExpenseTypeCode(String val) {
    expenseTypeCode = val;
    _rebuildFilteredBudgetSources();
  }

  Future<void> loadPartyOptions() async {
    try {
      partyOptions = await _repository.getPartyNames();
    } catch (_) {
      partyOptions = const [];
    }
    _safeNotify();
  }

  Future<List<Map<String, dynamic>>> loadPartyRowsForPicker() =>
      _repository.getPartyRowsForPickerLocal();

  /// แถวผู้รับสำหรับ picker จาก SQLite (`party` + expense) — ไม่รอเซิร์ฟเวอร์
  Future<List<Map<String, dynamic>>> loadReceiverPartyRowsLocalForPicker() =>
      _repository.getPartyRowsForPickerLocal();

  Future<String?> fetchDocNo({
    required String tableName,
    required String docDate,
  }) async {
    final incomeRepository =
        ServiceLocator.instance.get<income_offline.IncomeRepository>();
    final result = await GetDocNo(incomeRepository)
        .call(GetDocNoParams(tableName: tableName, docDate: docDate));
    return result.fold((failure) {
      error = failure.message;
      _safeNotify();
      return null;
    }, (docNo) => docNo);
  }

  Future<void> refreshPartyMasterCacheFromServer() async {
    final incomeRepository =
        ServiceLocator.instance.get<income_offline.IncomeRepository>();
    await incomeRepository.refreshPartyMasterCacheFromServer();
  }

  List<Map<String, dynamic>> _toDataList(List<ExpenseModel> items) => items
      .map((e) => {
            'id': e.id,
            'docno': e.docno,
            'docdate': e.docdate,
            'detail': e.detail,
            'amount': e.amount,
            'remark': e.remark,
            'refBudgetSource': e.refBudgetSource,
            'refParty': e.refParty,
            'partyName': e.partyName,
            'created': e.created,
            'synced': e.synced,
            'refExpenseType': e.refExpenseType,
            'refFundCategory': e.refFundCategory,
            'refMoneyType': e.refMoneyType,
            'docStatus': e.docStatus,
          })
      .toList();
}
