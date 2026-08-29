import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/rules/income_budget_source_rule.dart';
import '../../data/repositories/income_repository_offline.dart' as offline;
import '../../domain/entities/lookup_item.dart';
import '../../domain/repositories/income_repository.dart';
import '../../domain/usecases/create_income.dart';
import '../../domain/usecases/get_doc_no.dart';
import '../../domain/usecases/get_income_list.dart';
import '../../domain/usecases/get_lookup_items.dart';
import '../../../../core/usecases/usecase.dart';

class IncomeProvider extends ChangeNotifier {
  List<List<String>> monneyType;
  String monneyTypeCode;
  List<List<String>> incomeType;
  String incomeTypeCode;
  List<List<String>> budgetSource;
  List<List<String>> _allBudgetSource;

  /// รายการแหล่งงบทั้งหมดจาก DB (ก่อน filter ตาม incomeTypeCode)
  List<List<String>> get allBudgetSource => _allBudgetSource;
  String budgetSourceCode;
  List<List<String>> partyOptions = const [];

  /// [id, label] จาก `receipt_book` สถานะพร้อมใช้
  List<List<String>> receiptBookOptions = const [];
  List<Map<String, dynamic>> receiptBookRows = const [];
  bool isReceiptBookLoading = false;

  bool isLoading = false;
  String? error;
  bool _disposed = false;

  // ─── Per-field loading flags (อิสระต่อกัน) ───────────────────────
  bool isIncomeTypeLoading = true;
  bool isBudgetSourceLoading = true;
  bool isMoneyTypeLoading = true;

  late final IncomeRepository _repository;
  int _budgetSourceLoadGeneration = 0;

  IncomeProvider({
    required this.monneyType,
    required this.incomeType,
    this.budgetSource = const [],
    List<List<String>>? allBudgetSource,
    this.monneyTypeCode = '',
    this.incomeTypeCode = '',
    this.budgetSourceCode = '',
    IncomeRepository? repository,
  }) : _allBudgetSource = allBudgetSource ?? const [] {
    _repository =
        repository ?? ServiceLocator.instance.get<offline.IncomeRepository>();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ─── Loading methods ────────────────────────────────────────────────────────

  /// Stage 1: แสดง local ทันที
  /// Stage 2: background pull → reload เงียบๆ ถ้ามีข้อมูลใหม่
  Future<void> loadIncomeList(Function(List<dynamic>) onDataLoaded) async {
    // Stage 1: Local data — ตอบ UI ทันที
    final localResult = await GetIncomeList(_repository).call(NoParams());
    localResult.fold(
      (failure) {
        error = failure.message;
        _safeNotify();
      },
      (items) {
        if (!_disposed) onDataLoaded(_toDataList(items));
      },
    );

    // Stage 2: Background pull — ไม่บล็อก UI
    unawaited(
      (_repository as offline.IncomeRepository)
          .backgroundPull()
          .then((_) async {
        if (_disposed) return;
        final refreshed = await GetIncomeList(_repository).call(NoParams());
        refreshed.fold(
          (_) {}, // ไม่มีข้อมูลใหม่หรือ error — ไม่ต้องทำอะไร
          (items) {
            if (!_disposed) onDataLoaded(_toDataList(items));
          },
        );
      }),
    );
  }

  Future<void> loadMoneyTypes() async {
    isMoneyTypeLoading = true;
    // Stage 1: Local data ทันที
    final localResult = await GetMoneyTypes(_repository).call(NoParams());
    localResult.fold(
      (failure) => error = failure.message,
      (items) => _applyMoneyTypes(items),
    );
    isMoneyTypeLoading = false;
    _safeNotify();

    // Stage 2: Background pull lookup tables
    unawaited(
      (_repository as offline.IncomeRepository)
          .backgroundPullLookups()
          .then((_) async {
        if (_disposed) return;
        final refreshed = await GetMoneyTypes(_repository).call(NoParams());
        refreshed.fold((_) {}, (items) {
          _applyMoneyTypes(items);
          _safeNotify();
        });
      }),
    );
  }

  Future<void> loadIncomeTypes() async {
    isIncomeTypeLoading = true;
    // Stage 1: Local data ทันที
    final localResult = await GetIncomeTypes(_repository).call(NoParams());
    localResult.fold(
      (failure) => error = failure.message,
      (items) => _applyIncomeTypes(items),
    );
    isIncomeTypeLoading = false;
    _safeNotify();

    // Stage 2: Background pull (shared with loadMoneyTypes — ทำพร้อมกัน)
    unawaited(
      (_repository as offline.IncomeRepository)
          .backgroundPullLookups()
          .then((_) async {
        if (_disposed) return;
        final refreshed = await GetIncomeTypes(_repository).call(NoParams());
        refreshed.fold((_) {}, (items) {
          _applyIncomeTypes(items);
          _safeNotify();
        });
      }),
    );
  }

  Future<void> loadBudgetSources() async {
    final generation = ++_budgetSourceLoadGeneration;
    isBudgetSourceLoading = true;
    final localResult = await GetBudgetSources(_repository).call(NoParams());
    if (generation != _budgetSourceLoadGeneration || _disposed) return;
    localResult.fold(
      (failure) => error = failure.message,
      (items) => _applyBudgetSources(items),
    );
    isBudgetSourceLoading = false;
    _safeNotify();
  }

  Future<void> loadBudgetSourcesForSelectedIncomeType() {
    return loadBudgetSourcesForIncomeType(incomeTypeCode);
  }

  Future<void> loadBudgetSourcesForIncomeType(String incomeTypeId) async {
    final requestedIncomeTypeId = incomeTypeId.trim();
    incomeTypeCode = requestedIncomeTypeId;
    final generation = ++_budgetSourceLoadGeneration;
    isBudgetSourceLoading = true;
    budgetSource = const [];
    budgetSourceCode = '';
    _safeNotify();

    if (requestedIncomeTypeId.isEmpty) {
      isBudgetSourceLoading = false;
      _safeNotify();
      return;
    }

    final result = await GetBudgetSourcesForIncomeType(_repository).call(
      BudgetSourcesForIncomeTypeParams(requestedIncomeTypeId),
    );
    if (generation != _budgetSourceLoadGeneration || _disposed) return;
    result.fold(
      (failure) => error = failure.message,
      (items) => _applyBudgetSourcesForIncomeType(
        items,
        requestedIncomeTypeId,
      ),
    );
    isBudgetSourceLoading = false;
    _safeNotify();
  }

  Future<void> loadBudgetSourceContextById(String budgetSourceId) async {
    final sourceId = budgetSourceId.trim();
    final generation = ++_budgetSourceLoadGeneration;
    isBudgetSourceLoading = true;
    _safeNotify();

    if (sourceId.isEmpty) {
      budgetSource = const [];
      budgetSourceCode = '';
      isBudgetSourceLoading = false;
      _safeNotify();
      return;
    }

    final sourceResult = await GetBudgetSourceById(_repository).call(
      BudgetSourceByIdParams(sourceId),
    );
    if (generation != _budgetSourceLoadGeneration || _disposed) return;
    if (sourceResult.isLeft) {
      error = sourceResult.left.message;
      isBudgetSourceLoading = false;
      _safeNotify();
      return;
    }

    final source = sourceResult.right;
    if (source == null) {
      budgetSource = const [];
      budgetSourceCode = '';
      isBudgetSourceLoading = false;
      _safeNotify();
      return;
    }

    final sourceIncomeTypeId = (source.refFundCategory ?? '').trim();
    if (sourceIncomeTypeId.isEmpty) {
      incomeTypeCode = '';
      _applyBudgetSourcesForIncomeType(
        [source],
        '',
        preferredBudgetSourceCode: sourceId,
      );
      isBudgetSourceLoading = false;
      _safeNotify();
      return;
    }

    incomeTypeCode = sourceIncomeTypeId;
    final scopedResult = await GetBudgetSourcesForIncomeType(_repository).call(
      BudgetSourcesForIncomeTypeParams(sourceIncomeTypeId),
    );
    if (generation != _budgetSourceLoadGeneration || _disposed) return;
    scopedResult.fold(
      (failure) => error = failure.message,
      (items) {
        final scopedItems = items.any((item) => item.id == sourceId)
            ? items
            : <LookupItem>[...items, source];
        _applyBudgetSourcesForIncomeType(
          scopedItems,
          sourceIncomeTypeId,
          preferredBudgetSourceCode: sourceId,
        );
      },
    );
    isBudgetSourceLoading = false;
    _safeNotify();
  }

  void _applyPartyLookupItems(List<LookupItem> items) {
    final seen = <String>{};
    partyOptions =
        items.map((e) => [e.id.toString(), e.name.toString()]).where((row) {
      if (row[1].trim().isEmpty) return false;
      if (seen.contains(row[1].trim().toLowerCase())) return false;
      seen.add(row[1].trim().toLowerCase());
      return true;
    }).toList();
    error = null;
  }

  Future<void> loadPartyOptions() async {
    final result = await _repository.getParties();
    result.fold(
      (failure) => error = failure.message,
      _applyPartyLookupItems,
    );
    _safeNotify();
  }

  /// รายชื่อผู้จ่ายจาก localdb (`party` + income) — ไม่รอเซิร์ฟเวอร์
  Future<void> loadPartyOptionsFromLocalIncome() async {
    final result = await _repository.getPartiesFromLocalIncome();
    result.fold(
      (failure) => error = failure.message,
      _applyPartyLookupItems,
    );
    _safeNotify();
  }

  /// แถวผู้จ่ายสำหรับ picker จากตาราง `party` + income (ไม่รอเซิร์ฟเวอร์)
  Future<List<Map<String, dynamic>>> loadPayerPartyRowsLocalForPicker() async {
    final result = await _repository.getPayerPartyRowsLocalForPicker();
    return result.fold((failure) {
      error = failure.message;
      _safeNotify();
      return <Map<String, dynamic>>[];
    }, (rows) {
      error = null;
      return rows;
    });
  }

  Future<void> loadAvailableReceiptBooks() async {
    isReceiptBookLoading = true;
    _safeNotify();
    final result = await _repository.getAvailableReceiptBooks();
    result.fold(
      (failure) {
        error = failure.message;
        receiptBookOptions = const [];
        receiptBookRows = const [];
      },
      (rows) {
        error = null;
        receiptBookRows =
            rows.map((r) => Map<String, dynamic>.from(r)).toList();
        receiptBookOptions = rows
            .map((r) => <String>[
                  r['id']?.toString() ?? '',
                  _receiptBookDropdownLabel(r),
                ])
            .where((e) => e[0].isNotEmpty && e[1].trim().isNotEmpty)
            .toList();
      },
    );
    isReceiptBookLoading = false;
    _safeNotify();
  }

  Map<String, dynamic>? receiptBookById(String bookId) {
    final id = bookId.trim();
    if (id.isEmpty) return null;
    for (final row in receiptBookRows) {
      if (row['id']?.toString() == id) return row;
    }
    return null;
  }

  Future<String?> suggestedNextReceiptNo(String bookId) async {
    final result = await _repository.getSuggestedNextReceiptNo(bookId);
    return result.fold((failure) {
      error = failure.message;
      _safeNotify();
      return null;
    }, (value) {
      error = null;
      return value;
    });
  }

  static String _receiptBookDropdownLabel(Map<String, dynamic> r) {
    final bookNo = (r['book_no']?.toString() ?? '').trim();
    final fy = (r['fiscal_year']?.toString() ?? '').trim();
    final rt = (r['receipt_type']?.toString() ?? '').trim();
    final parts = <String>[if (bookNo.isNotEmpty) bookNo];
    if (fy.isNotEmpty) parts.add('ปี $fy');
    if (rt.isNotEmpty) parts.add(rt);
    return parts.join(' · ');
  }

  Future<void> cachePartyMasterRowsFromServer(
    List<Map<String, dynamic>> rows,
  ) async {
    await _repository.cachePartyMasterRowsFromServer(rows);
  }

  Future<void> refreshPartyMasterCacheFromServer() async {
    await _repository.refreshPartyMasterCacheFromServer();
  }

  Future<String?> fetchDocNo(
      {required String tableName, required String docDate}) async {
    final result = await GetDocNo(_repository)
        .call(GetDocNoParams(tableName: tableName, docDate: docDate));
    return result.fold((failure) {
      error = failure.message;
      _safeNotify();
      return null;
    }, (docNo) => docNo);
  }

  // ─── Save methods ────────────────────────────────────────────────────────────

  Future<bool> saveIncome({
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    String? bankReference,
    required String partyName,
    String? refParty,
    required String refUser,
    required List<Map<String, dynamic>> subData,
    String? refBankAccount,
    String? receiptBookId,
    String? receiptNo,
    bool bumpBudgetSourceBudgetAmount = true,
    String docStatus = 'posted',
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();

    final result = await CreateIncome(_repository).call(CreateIncomeParams(
      token: token,
      docno: docno,
      docdate: docdate,
      amount: amount,
      detail: detail,
      remark: remark,
      bankReference: bankReference,
      partyName: partyName,
      refParty: refParty,
      refUser: refUser,
      refMoneyType: monneyTypeCode,
      refIncomeType: incomeTypeCode,
      refBudgetSource: budgetSourceCode.isEmpty ? null : budgetSourceCode,
      subData: subData,
      refBankAccount: refBankAccount,
      receiptBookId: receiptBookId,
      receiptNo: receiptNo,
      bumpBudgetSourceBudgetAmount: bumpBudgetSourceBudgetAmount,
      docStatus: docStatus,
    ));

    result.fold(
      (failure) => error = failure.message,
      (_) => error = null,
    );

    isLoading = false;
    _safeNotify();
    return error == null;
  }

  Future<bool> updateIncome({
    required String localId,
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    String? bankReference,
    required String partyName,
    required String refUser,
    required List<Map<String, dynamic>> subData,
    String? changeReason,
    String? refBankAccount,
    String? receiptBookId,
    String? receiptNo,
    bool bumpBudgetSourceBudgetAmount = true,
    String? docStatus,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();

    final repo = _repository as offline.IncomeRepository;
    final result = await repo.updateIncome(
      localId: localId,
      token: token,
      docno: docno,
      docdate: docdate,
      amount: amount,
      detail: detail,
      remark: remark,
      bankReference: bankReference,
      partyName: partyName,
      refUser: refUser,
      refMoneyType: monneyTypeCode,
      refIncomeType: incomeTypeCode,
      refBudgetSource: budgetSourceCode.isEmpty ? null : budgetSourceCode,
      subData: subData,
      changeReason: changeReason,
      refBankAccount: refBankAccount,
      receiptBookId: receiptBookId,
      receiptNo: receiptNo,
      bumpBudgetSourceBudgetAmount: bumpBudgetSourceBudgetAmount,
      docStatus: docStatus,
    );

    result.fold(
      (failure) => error = failure.message,
      (_) => error = null,
    );

    isLoading = false;
    _safeNotify();
    return error == null;
  }

  Future<String?> upsertAutoDraft({
    String? localId,
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    String? bankReference,
    required String partyName,
    String? refParty,
    required String refUser,
    required List<Map<String, dynamic>> subData,
    String? refBankAccount,
  }) async {
    final repo = _repository as offline.IncomeRepository;
    final result = await repo.upsertDraftIncome(
      localId: localId,
      token: token,
      docno: docno,
      docdate: docdate,
      amount: amount,
      detail: detail,
      remark: remark,
      bankReference: bankReference,
      partyName: partyName,
      refParty: refParty,
      refUser: refUser,
      refMoneyType: monneyTypeCode,
      refIncomeType: incomeTypeCode,
      refBudgetSource: budgetSourceCode.isEmpty ? null : budgetSourceCode,
      subData: subData,
      refBankAccount: refBankAccount,
    );

    return result.fold((failure) {
      error = failure.message;
      return null;
    }, (id) {
      error = null;
      return id;
    });
  }

  Future<bool> deleteIncome({
    required String localId,
    required String token,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();

    final result = await _repository.deleteIncomeOfflineFirst(
      localId: localId,
      token: token,
    );

    result.fold(
      (failure) => error = failure.message,
      (_) => error = null,
    );

    isLoading = false;
    _safeNotify();
    return error == null;
  }

  // ─── State mutation helpers (kept for backward compatibility) ────────────────

  void addMonneyType(List<List<String>> val) {
    monneyType = val;
    _safeNotify();
  }

  void addMonneyTypeCode(String val) {
    monneyTypeCode = val;
    _safeNotify();
  }

  void addIncomeType(List<List<String>> val) {
    incomeType = val;
    _safeNotify();
  }

  void addIncomeTypeCode(String val) {
    incomeTypeCode = val;
    _applyBudgetSourcesByIncomeType();
    _safeNotify();
  }

  void addBudgetSource(List<List<String>> val) {
    budgetSource = val;
    _allBudgetSource = val;
    _safeNotify();
  }

  void addBudgetSourceCode(String val) {
    budgetSourceCode = val;
    _safeNotify();
  }

  void syncIncomeTypeFromBudgetSource(String sourceId) {
    final source = _allBudgetSource.firstWhere(
      (item) => item.isNotEmpty && item[0] == sourceId,
      orElse: () => const <String>[],
    );
    if (source.length >= 3 && source[2].isNotEmpty) {
      incomeTypeCode = source[2];
      _applyBudgetSourcesByIncomeType();
      budgetSourceCode = sourceId;
      _safeNotify();
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _toDataList(List<dynamic> items) => items
      .map((e) => {
            'id': e.id,
            'docno': e.docno,
            'docdate': e.docdate,
            'detail': e.detail,
            'amount': e.amount,
            'remark': e.remark,
            'bankReference': e.bankReference,
            'bank_reference': e.bankReference,
            'created': e.created,
            'refBudgetSource': e.refBudgetSource,
            'budgetSourceName': e.budgetSourceName,
            'refIncomeType': e.refIncomeType,
            'refParty': e.refParty,
            'partyName': e.partyName,
            'refMoneyType': e.refMoneyType,
            'docStatus': e.docStatus,
            'doc_status': e.docStatus,
            'moneyDomain': e.moneyDomain,
            'postedAt': e.postedAt,
            'changeReason': e.changeReason,
            'synced': (e as dynamic).synced ?? true,
          })
      .toList();

  void _applyMoneyTypes(List<dynamic> items) {
    monneyType = items
        .asMap()
        .entries
        .map<List<String>>(
            (e) => [e.value.id as String, e.value.name as String])
        .toList();
    if (items.isNotEmpty) monneyTypeCode = items.first.id;
    error = null;
  }

  void _applyIncomeTypes(List<dynamic> items) {
    incomeType = items
        .asMap()
        .entries
        .map<List<String>>((e) => [
              e.value.id as String,
              e.value.name as String,
              e.value.code?.toString() ?? '',
            ])
        .toList();
    error = null;
  }

  void _applyBudgetSources(List<dynamic> items) {
    _allBudgetSource = items.asMap().entries.map<List<String>>((e) {
      final v = e.value;
      final id = v.id as String;
      final name = v.name as String;
      final cat = v.refFundCategory?.toString() ?? '';
      final bank = v.refBankAccount?.toString().trim() ?? '';
      return [id, name, cat, bank];
    }).toList();
    _applyBudgetSourcesByIncomeType();
    error = null;
  }

  void _applyBudgetSourcesForIncomeType(
    List<LookupItem> items,
    String incomeTypeId, {
    String preferredBudgetSourceCode = '',
  }) {
    final scopedIncomeTypeId = incomeTypeId.trim();
    _allBudgetSource = items.map<List<String>>((v) {
      final cat = (v.refFundCategory ?? scopedIncomeTypeId).trim();
      final bank = v.refBankAccount?.trim() ?? '';
      return [v.id, v.name, cat, bank];
    }).toList();
    budgetSource = _allBudgetSource
        .map<List<String>>((item) => [
              item[0],
              item[1],
              if (item.length >= 4) item[3] else '',
            ])
        .toList();

    final preferred = preferredBudgetSourceCode.trim();
    if (preferred.isNotEmpty &&
        budgetSource.any((item) => item.isNotEmpty && item[0] == preferred)) {
      budgetSourceCode = preferred;
    } else if (!budgetSource.any((item) => item[0] == budgetSourceCode)) {
      budgetSourceCode =
          IncomeBudgetSourceRule.pickDefaultBudgetSourceCode(budgetSource);
    }
    error = null;
  }

  void _applyBudgetSourcesByIncomeType() {
    if (incomeTypeCode.isEmpty) {
      budgetSource = const [];
      budgetSourceCode = '';
      return;
    }

    budgetSource = _allBudgetSource
        .where((item) => item.length >= 3 && item[2] == incomeTypeCode)
        .map<List<String>>((item) => [
              item[0],
              item[1],
              if (item.length >= 4) item[3] else '',
            ])
        .toList();
    final selectedStillExists =
        budgetSource.any((item) => item[0] == budgetSourceCode);
    if (!selectedStillExists) {
      budgetSourceCode =
          IncomeBudgetSourceRule.pickDefaultBudgetSourceCode(budgetSource);
    }
  }

  /// บัญชีธนาคารจาก master แหล่งเงินตามรายการที่เลือก (ว่าง = ยังไม่ตั้งที่แหล่งเงิน)
  String? get bankAccountIdForSelectedBudgetSource {
    if (budgetSourceCode.isEmpty) return null;
    for (final row in budgetSource) {
      if (row.isNotEmpty && row[0] == budgetSourceCode) {
        if (row.length >= 3) {
          final b = row[2].trim();
          return b.isEmpty ? null : b;
        }
        return null;
      }
    }
    return null;
  }
}
