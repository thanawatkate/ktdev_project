import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/local_data_source/expense_local_data_source.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/features/expense/data/datasources/expense_remote_data_source.dart';
import 'package:saccm/features/expense/data/repositories/expense_repository_offline.dart';
import 'package:saccm/features/income/data/models/lookup_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _FakeNetworkInfo implements NetworkInfoService {
  _FakeNetworkInfo(this._connected);
  bool _connected;

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();

  void setConnected(bool v) => _connected = v;
}

class _FakeExpenseLocalDataSource extends ExpenseLocalDataSource {
  final List<ExpenseModel> _saved = [];
  final List<String> _synced = [];
  final List<Map<String, dynamic>> _subs = [];
  final List<Map<String, dynamic>> _payCheques = [];

  @override
  Future<void> init() async {} // skip SQLite

  @override
  Future<void> saveExpenseSub({
    required String id,
    required String refExpense,
    String? refExpenseType,
    String? refFundCategory,
    String? refMoneyType,
    required String amount,
    required String remark,
    bool synced = false,
  }) async {
    _subs.add({
      'id': id,
      'refExpense': refExpense,
      'refExpenseType': refExpenseType,
      'refFundCategory': refFundCategory,
      'refMoneyType': refMoneyType,
      'amount': amount,
      'remark': remark,
    });
  }

  @override
  Future<void> deleteExpenseSubsForExpense(String refExpense) async {
    _subs.removeWhere((e) => e['refExpense'] == refExpense);
  }

  @override
  Future<void> savePayCheque({
    required String id,
    required String refExpense,
    String? refChequeAccount,
    required String chequeamount,
    String? chequeno,
    String? clearedAt,
    String remark = '',
    bool synced = false,
  }) async {
    _payCheques.add({
      'id': id,
      'refExpense': refExpense,
      'refChequeAccount': refChequeAccount,
      'chequeamount': chequeamount,
      'chequeno': chequeno,
      'remark': remark,
    });
  }

  @override
  Future<void> deletePayChequesForExpense(String refExpense) async {
    _payCheques.removeWhere((e) => e['refExpense'] == refExpense);
  }

  @override
  Future<List<Map<String, dynamic>>> getExpenseSubsForExpense(
    String refExpense,
  ) async {
    return _subs
        .where((e) => e['refExpense'] == refExpense)
        .map(Map<String, dynamic>.from)
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getPayChequeFirstForExpense(
    String refExpense,
  ) async {
    final hit =
        _payCheques.where((e) => e['refExpense'] == refExpense).toList();
    if (hit.isEmpty) return null;
    return Map<String, dynamic>.from(hit.first);
  }

  @override
  Future<void> saveExpense(ExpenseModel expense, {bool synced = true}) async {
    _saved.add(expense);
  }

  @override
  Future<void> saveExpenses(List<ExpenseModel> expenses) async {
    _saved.addAll(expenses);
  }

  @override
  Future<List<ExpenseModel>> getAllExpenses() async => List.from(_saved);

  @override
  Future<ExpenseModel?> getExpenseById(String id) async {
    try {
      return _saved.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteExpense(String id) async {
    _saved.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> clearAllExpenses() async => _saved.clear();

  @override
  Future<void> markAsSynced(String id) async => _synced.add(id);

  List<ExpenseModel> get savedItems => List.from(_saved);
}

class _FakePendingService extends PendingRequestsService {
  final List<PendingRequest> _items = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> addPendingRequest({
    required String id,
    required String method,
    required String endpoint,
    String? payload,
  }) async {
    _items.add(PendingRequest(
      id: id,
      method: method,
      endpoint: endpoint,
      payload: payload,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<List<PendingRequest>> getPendingRequests() async => List.from(_items);

  @override
  Future<void> removePendingRequest(String id) async =>
      _items.removeWhere((e) => e.id == id);

  @override
  Future<void> updateAttempts(String id, int attempts) async {}

  @override
  Future<void> clearAllPending() async => _items.clear();

  List<PendingRequest> get items => List.from(_items);
}

class _FakeExpenseRemoteDataSource implements ExpenseRemoteDataSource {
  final List<ExpenseModel> items;
  _FakeExpenseRemoteDataSource({this.items = const []});

  @override
  Future<List<ExpenseModel>> getExpenseList({int page = 1}) async => items;

  @override
  Future<List<LookupItemModel>> getParties() async => const [];
}

class _FakeBudgetSourceLocalDataSource extends BudgetSourceLocalDataSource {
  final List<({String budgetRowId, double spendAmount})> spendCalls = [];
  final List<({String budgetRowId, double amountDelta})> adjustCalls = [];

  @override
  Future<void> applyExpenseSpend({
    required String budgetRowId,
    required double spendAmount,
  }) async {
    spendCalls.add((budgetRowId: budgetRowId, spendAmount: spendAmount));
  }

  @override
  Future<void> adjustPostedExpenseUsedAmount({
    required String budgetRowId,
    required double amountDelta,
  }) async {
    adjustCalls.add((budgetRowId: budgetRowId, amountDelta: amountDelta));
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

ExpenseRepository _buildRepo({
  required bool online,
  required _FakeExpenseLocalDataSource localDs,
  required _FakePendingService pendingService,
  BudgetSourceLocalDataSource? budgetSourceLocalDataSource,
  ExpenseRemoteDataSource? remoteDataSource,
}) {
  final networkInfo = _FakeNetworkInfo(online);
  final syncService = SyncService(
    networkInfo: networkInfo,
    pendingService: pendingService,
    requestExecutor: (_) async {}, // no-op — we don't test sync replay here
  );
  return ExpenseRepository(
    localDataSource: localDs,
    budgetSourceLocalDataSource: budgetSourceLocalDataSource,
    networkInfo: networkInfo,
    syncService: syncService,
    remoteDataSource:
        remoteDataSource ?? _FakeExpenseRemoteDataSource(items: const []),
  );
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExpenseRepository', () {
    late _FakeExpenseLocalDataSource localDs;
    late _FakePendingService pendingService;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'license_activated': true,
        'product_tier': 'online',
      });
      localDs = _FakeExpenseLocalDataSource();
      pendingService = _FakePendingService();
    });

    test('createExpense offline: saves locally and queues request', () async {
      final repo = _buildRepo(
        online: false,
        localDs: localDs,
        pendingService: pendingService,
      );

      await repo.createExpense(
        token: 'tok',
        docno: 'EXP001',
        docdate: '2026-04-11',
        amount: '500',
        detail: 'ค่าใช้จ่าย',
        remark: '-',
        partyName: 'ผู้รับเงินทดสอบ',
        refMember: 'M001',
        subData: [
          {
            'amount': '500',
            'remark': '-',
            'refmoneytype': '1',
          },
        ],
      );

      expect(localDs.savedItems, hasLength(1));
      expect(localDs.savedItems.first.docno, 'EXP001');
      expect(localDs.savedItems.first.amount, '500');

      final pending = pendingService.items;
      expect(pending, hasLength(1));
      expect(pending.first.id, startsWith('expense_create_'));
      expect(pending.first.endpoint, contains('expense'));
      expect(pending.first.method, 'POST');
    });

    test('createExpense online: saves locally and request is processed',
        () async {
      final repo = _buildRepo(
        online: true,
        localDs: localDs,
        pendingService: pendingService,
      );

      await repo.createExpense(
        token: 'tok',
        docno: 'EXP002',
        docdate: '2026-04-11',
        amount: '1000',
        detail: 'ค่าใช้จ่ายออนไลน์',
        remark: '',
        partyName: 'ผู้รับเงินทดสอบออนไลน์',
        refMember: 'M002',
        subData: [
          {
            'amount': '1000',
            'remark': '',
            'refmoneytype': '1',
          },
        ],
      );

      // Expense is saved to local cache regardless of connectivity
      expect(localDs.savedItems, hasLength(1));
      expect(localDs.savedItems.first.docno, 'EXP002');

      // Local-first: request is always queued; test executor is no-op so item
      // stays until an explicit replay/drain (not exercised here).
      await Future<void>.delayed(Duration.zero);
      expect(pendingService.items, hasLength(1));
      expect(pendingService.items.first.method, 'POST');
    });

    test('getExpenseList returns locally saved items', () async {
      final repo = _buildRepo(
        online: false,
        localDs: localDs,
        pendingService: pendingService,
      );

      await localDs.saveExpense(
        ExpenseModel(
          id: '1',
          docno: 'EXP003',
          docdate: '2026-04-11',
          detail: 'test',
          amount: '200',
          remark: '',
          created: DateTime.now().toIso8601String(),
        ),
      );

      final list = await repo.getExpenseList();
      expect(list, hasLength(1));
      expect(list.first.docno, 'EXP003');
    });

    test('createExpense payload contains required backend fields', () async {
      final repo = _buildRepo(
        online: false,
        localDs: localDs,
        pendingService: pendingService,
      );

      await repo.createExpense(
        token: 'mytoken',
        docno: 'EXP010',
        docdate: '2026-04-11',
        amount: '750',
        detail: 'ครุภัณฑ์',
        remark: 'รายการทดสอบ',
        partyName: 'ผู้รับเงิน',
        refMember: 'M010',
        subData: [
          {
            'amount': '750',
            'remark': 'รายการทดสอบ',
            'refmoneytype': '2',
          },
        ],
      );

      final pending = pendingService.items.first;
      expect(pending.payload, isNotNull);

      final decoded = jsonDecode(pending.payload!) as Map<String, dynamic>;
      expect(decoded['token'], 'mytoken');
      expect(decoded['docno'], 'EXP010');
      expect(decoded['refmember'], 'M010');
      expect(decoded, contains('subdata'));
    });

    test('createExpense throws when subData is empty', () async {
      final repo = _buildRepo(
        online: false,
        localDs: localDs,
        pendingService: pendingService,
      );

      await expectLater(
        repo.createExpense(
          token: 'tok',
          docno: 'EXP_EMPTY',
          docdate: '2026-04-11',
          amount: '1',
          detail: 'd',
          remark: '',
          partyName: 'p',
          refMember: 'm',
          subData: const [],
        ),
        throwsArgumentError,
      );
    });

    test(
        'createExpense fills refmoneytype from fallback when omitted in subData',
        () async {
      final repo = _buildRepo(
        online: false,
        localDs: localDs,
        pendingService: pendingService,
      );

      await repo.createExpense(
        token: 'tok',
        docno: 'EXP_FB',
        docdate: '2026-04-11',
        amount: '100',
        detail: 'd',
        remark: '',
        partyName: 'p',
        refMember: 'm',
        subData: [
          {'amount': '100', 'remark': 'x'},
        ],
        lineRefMoneyTypeFallback: '5',
      );

      final pending = pendingService.items.last;
      final decoded = jsonDecode(pending.payload!) as Map<String, dynamic>;
      final sub = jsonDecode(decoded['subdata'] as String) as List<dynamic>;
      expect((sub.first as Map)['refmoneytype'], '5');
    });

    test('createExpense posted applies budget spend once', () async {
      final budgetDs = _FakeBudgetSourceLocalDataSource();
      final repo = _buildRepo(
        online: false,
        localDs: localDs,
        pendingService: pendingService,
        budgetSourceLocalDataSource: budgetDs,
      );

      await repo.createExpense(
        token: 'tok',
        docno: 'EXP_POSTED',
        docdate: '2026-04-11',
        amount: '1,250.50',
        detail: 'd',
        remark: '',
        partyName: 'p',
        refMember: 'm',
        refBudgetSource: 'BS-1',
        subData: [
          {'amount': '1250.50', 'remark': 'x', 'refmoneytype': '1'},
        ],
        docStatus: 'posted',
      );

      expect(budgetDs.spendCalls, hasLength(1));
      expect(budgetDs.spendCalls.first.budgetRowId, 'BS-1');
      expect(budgetDs.spendCalls.first.spendAmount, 1250.50);
      expect(budgetDs.adjustCalls, isEmpty);
    });

    test('updateExpense posted same budget adjusts used amount by delta',
        () async {
      final budgetDs = _FakeBudgetSourceLocalDataSource();
      final repo = _buildRepo(
        online: false,
        localDs: localDs,
        pendingService: pendingService,
        budgetSourceLocalDataSource: budgetDs,
      );
      await localDs.saveExpense(
        ExpenseModel(
          id: 'expense-1',
          docno: 'EXP_DELTA',
          docdate: '2026-04-11',
          detail: 'old',
          amount: '100',
          remark: '',
          refBudgetSource: 'BS-1',
          partyName: 'p',
          created: DateTime.now().toIso8601String(),
          docStatus: 'posted',
        ),
      );

      await repo.updateExpense(
        localId: 'expense-1',
        token: 'tok',
        docno: 'EXP_DELTA',
        docdate: '2026-04-11',
        amount: '140',
        detail: 'new',
        remark: '',
        partyName: 'p',
        refMember: 'm',
        refBudgetSource: 'BS-1',
        subData: [
          {'amount': '140', 'remark': 'x', 'refmoneytype': '1'},
        ],
      );

      expect(budgetDs.spendCalls, isEmpty);
      expect(budgetDs.adjustCalls, hasLength(1));
      expect(budgetDs.adjustCalls.first.budgetRowId, 'BS-1');
      expect(budgetDs.adjustCalls.first.amountDelta, 40);
    });

    test('updateExpense posted moved budget reverses old and applies new',
        () async {
      final budgetDs = _FakeBudgetSourceLocalDataSource();
      final repo = _buildRepo(
        online: false,
        localDs: localDs,
        pendingService: pendingService,
        budgetSourceLocalDataSource: budgetDs,
      );
      await localDs.saveExpense(
        ExpenseModel(
          id: 'expense-2',
          docno: 'EXP_MOVE',
          docdate: '2026-04-11',
          detail: 'old',
          amount: '100',
          remark: '',
          refBudgetSource: 'BS-OLD',
          partyName: 'p',
          created: DateTime.now().toIso8601String(),
          docStatus: 'posted',
        ),
      );

      await repo.updateExpense(
        localId: 'expense-2',
        token: 'tok',
        docno: 'EXP_MOVE',
        docdate: '2026-04-11',
        amount: '75',
        detail: 'new',
        remark: '',
        partyName: 'p',
        refMember: 'm',
        refBudgetSource: 'BS-NEW',
        subData: [
          {'amount': '75', 'remark': 'x', 'refmoneytype': '1'},
        ],
      );

      expect(budgetDs.spendCalls, isEmpty);
      expect(budgetDs.adjustCalls, hasLength(2));
      expect(budgetDs.adjustCalls[0].budgetRowId, 'BS-OLD');
      expect(budgetDs.adjustCalls[0].amountDelta, -100);
      expect(budgetDs.adjustCalls[1].budgetRowId, 'BS-NEW');
      expect(budgetDs.adjustCalls[1].amountDelta, 75);
    });
  });
}
