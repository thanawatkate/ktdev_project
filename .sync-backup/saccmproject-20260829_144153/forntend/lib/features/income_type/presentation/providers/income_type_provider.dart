import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/local_data_source/lookup_item_local_data_source.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/config.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';

import '../../domain/repositories/income_type_repository.dart';

class IncomeTypeProvider extends ChangeNotifier {
  static const String budgetSourceRequiredError =
      'กรุณาผูกแหล่งเงินอย่างน้อย 1 รายการก่อนบันทึกหมวดรายรับ';
  List<List<String>> moneyType;
  List<List<String>> sourceGroups;
  List<List<String>> budgetSources = [];
  Set<String> selectedBudgetSourceIds = <String>{};
  int? moneyTypeCode;
  int? sourceGroupCode;

  bool isLoading = false;
  String? error;
  bool _disposed = false;

  late final SyncService _syncService;
  late final IncomeTypeLocalDataSource _localDataSource;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  IncomeTypeProvider({
    required this.moneyType,
    required this.sourceGroups,
    this.moneyTypeCode = 1,
    IncomeTypeRepository? repository,
    IncomeTypeLocalDataSource? localDataSource,
  }) {
    _syncService = ServiceLocator.instance.get<SyncService>();
    _localDataSource = localDataSource ?? IncomeTypeLocalDataSource();
  }

  // ─── Loading methods ────────────────────────────────────────────────────────

  Future<void> loadPage() async {
    isLoading = true;
    error = null;
    _safeNotify();

    await Future.wait([
      loadSourceGroups(),
      loadBudgetSources(),
    ]);

    isLoading = false;
    _safeNotify();
  }

  Future<void> loadSourceGroups() async {
    final localGroups = await _localDataSource.queryMoneyGroupOptions();
    sourceGroups = localGroups
        .map((g) => [g['id']?.toString() ?? '', g['name']?.toString() ?? ''])
        .where((g) => g[0].isNotEmpty)
        .toList();
    if (sourceGroups.isNotEmpty) {
      sourceGroupCode = int.tryParse(sourceGroups.first[0]);
      error = null;
    } else {
      error = TransactionUiText.requestedDataNotFound;
    }
    _safeNotify();
  }

  Future<void> loadBudgetSources() async {
    final rows = await _localDataSource.queryBudgetSourceOptions();
    budgetSources = rows
        .map((r) => [r['id']?.toString() ?? '', r['name']?.toString() ?? ''])
        .where((x) => x[0].isNotEmpty)
        .toList();
    _safeNotify();
  }

  // ─── State mutation helpers ───────────────────────────────────────────────────

  void addMoneyType(List<List<String>> val) {
    moneyType = val;
    _safeNotify();
  }

  void addMoneyTypeCode(int val) {
    moneyTypeCode = val;
    _safeNotify();
  }

  void setSourceGroups(List<List<String>> val) {
    sourceGroups = val;
    _safeNotify();
  }

  void setSourceGroupCode(int val) {
    sourceGroupCode = val;
    _safeNotify();
  }

  void toggleBudgetSourceSelection(String budgetSourceId) {
    if (selectedBudgetSourceIds.contains(budgetSourceId)) {
      selectedBudgetSourceIds.remove(budgetSourceId);
    } else {
      selectedBudgetSourceIds.add(budgetSourceId);
    }
    _safeNotify();
  }

  void clearBudgetSourceSelections() {
    selectedBudgetSourceIds.clear();
    _safeNotify();
  }

  void selectAllBudgetSources() {
    selectedBudgetSourceIds = budgetSources.map((x) => x[0]).toSet();
    _safeNotify();
  }

  void applyBudgetSourceSelections(Set<String> ids) {
    selectedBudgetSourceIds = ids;
    _safeNotify();
  }

  Future<void> prepareBudgetSourceSelectionsForEditor(
    String? incomeTypeId,
  ) async {
    final id = incomeTypeId?.trim() ?? '';
    if (id.isEmpty) {
      selectedBudgetSourceIds.clear();
    } else {
      selectedBudgetSourceIds =
          await _localDataSource.queryLinkedBudgetSourceIds(id);
    }
    _safeNotify();
  }

  /// ตามคู่มือ พ.ศ. 2544 — หลายแหล่งต่อหมวดได้เฉพาะสายเดียวกัน (กลุ่มเงิน / ประเภทงบ / หมวดเดิม)
  Future<bool> validateLinkedBudgetSourcesForSchoolFinance(
      Set<String> masterIds) async {
    if (masterIds.length <= 1) {
      error = null;
      return true;
    }
    final rows = await _localDataSource.queryBudgetSourcesByIds(masterIds);
    if (rows.length != masterIds.length) {
      error = TransactionUiText.incomeTypeBudgetLinkMasterNotFound;
      _safeNotify();
      return false;
    }

    int? parseMoneyGroup(Object? v) {
      final n = int.tryParse(v?.toString().trim() ?? '');
      if (n != null && n > 0) return n;
      return null;
    }

    final moneyGroups =
        rows.map((r) => parseMoneyGroup(r['refmoneygroup'])).toList();
    if (moneyGroups.any((n) => n == null)) {
      error = TransactionUiText.incomeTypeBudgetLinkMoneyGroupRequiredForMany;
      _safeNotify();
      return false;
    }
    if (moneyGroups.toSet().length > 1) {
      error = TransactionUiText.incomeTypeBudgetLinkMoneyGroupConflict;
      _safeNotify();
      return false;
    }

    final budgetTypes = rows
        .map((r) => (r['budget_type'] ?? '').toString().trim())
        .map((x) => x.isEmpty ? '__EMPTY__' : x)
        .toSet();
    if (budgetTypes.length > 1) {
      error = TransactionUiText.incomeTypeBudgetLinkBudgetTypeConflict;
      _safeNotify();
      return false;
    }

    final fundCats = rows
        .map((r) => (r['refFundCategory'] ?? '').toString().trim())
        .toList();
    final nonEmptyFundCats = fundCats.where((s) => s.isNotEmpty).toSet();
    if (nonEmptyFundCats.length > 1) {
      error = TransactionUiText.incomeTypeBudgetLinkPriorIncomeTypeConflict;
      _safeNotify();
      return false;
    }
    final hasEmptyFund = fundCats.any((s) => s.isEmpty);
    if (hasEmptyFund && nonEmptyFundCats.isNotEmpty) {
      error = TransactionUiText.incomeTypeBudgetLinkFundCategoryMixed;
      _safeNotify();
      return false;
    }

    error = null;
    return true;
  }

  // ─── Save methods ────────────────────────────────────────────────────────────

  Future<bool> saveIncomeType({
    required String token,
    required String name,
    String remark = '',
  }) async {
    if (selectedBudgetSourceIds.isEmpty) {
      error = budgetSourceRequiredError;
      _safeNotify();
      return false;
    }
    if (!await validateLinkedBudgetSourcesForSchoolFinance(
        selectedBudgetSourceIds)) {
      return false;
    }
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final db = await AppDatabase().database;
      final now = DateTime.now().toIso8601String();
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      final normalizedName = name.trim();
      final normalizedRemark = remark.trim();
      final fallbackSourceGroupCode =
          sourceGroups.isNotEmpty ? int.tryParse(sourceGroups.first[0]) : null;
      final resolvedSourceGroupCode =
          sourceGroupCode ?? fallbackSourceGroupCode;

      await db.transaction((txn) async {
        await txn.insert('income_type', {
          'id': localId,
          'code': '',
          'name': normalizedName,
          'detail': normalizedRemark,
          'synced': 0,
          'lastModified': now,
        });

        for (final budgetSourceId in selectedBudgetSourceIds) {
          await txn.insert(
            'income_type_budget_source_map',
            {
              'id': 'itbsm_${localId}_$budgetSourceId',
              'refIncomeType': localId,
              'refBudgetSourceMaster': budgetSourceId,
              'synced': 0,
              'lastModified': now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        if (selectedBudgetSourceIds.isNotEmpty) {
          for (final budgetSourceId in selectedBudgetSourceIds) {
            await txn.update(
              'budget_source_master',
              {
                'refFundCategory': localId,
                'synced': 0,
                'lastModified': now,
              },
              where: 'id = ?',
              whereArgs: [budgetSourceId],
            );
          }
        }
      });

      await _syncService.addPendingRequest(
        id: 'income_type_create_$localId',
        method: 'POST',
        endpoint: '${baseurl}incometype',
        payload: jsonEncode({
          'token': token,
          'name': normalizedName,
          'remark': normalizedRemark,
          'refmoneygroup': resolvedSourceGroupCode ?? 0,
          'linked_budget_source_ids': selectedBudgetSourceIds.toList(),
        }),
      );

      await loadBudgetSources();
      error = null;
      return true;
    } catch (_) {
      error = 'บันทึกข้อมูลไม่สำเร็จ';
      return false;
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<bool> updateIncomeType({
    required String id,
    required String name,
    required String detail,
    required String token,
    required Set<String> selectedIds,
  }) async {
    if (selectedIds.isEmpty) {
      error = budgetSourceRequiredError;
      _safeNotify();
      return false;
    }
    if (!await validateLinkedBudgetSourcesForSchoolFinance(selectedIds)) {
      return false;
    }
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final db = await AppDatabase().database;
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        await txn.update(
          'income_type',
          {
            'name': name.trim(),
            'detail': detail.trim(),
            'synced': 0,
            'lastModified': now
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'income_type_budget_source_map',
          where: 'refIncomeType = ?',
          whereArgs: [id],
        );
        for (final bsId in selectedIds) {
          await txn.insert(
            'income_type_budget_source_map',
            {
              'id': 'itbsm_${id}_$bsId',
              'refIncomeType': id,
              'refBudgetSourceMaster': bsId,
              'synced': 0,
              'lastModified': now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        await txn.update(
          'budget_source_master',
          {
            'refFundCategory': null,
            'synced': 0,
            'lastModified': now,
          },
          where: 'refFundCategory = ?',
          whereArgs: [id],
        );
        if (selectedIds.isNotEmpty) {
          for (final bsId in selectedIds) {
            await txn.update(
              'budget_source_master',
              {
                'refFundCategory': id,
                'synced': 0,
                'lastModified': now,
              },
              where: 'id = ?',
              whereArgs: [bsId],
            );
          }
        }
      });
      await _syncService.addPendingRequest(
        id: 'income_type_update_$id',
        method: 'PATCH',
        endpoint: '${baseurl}incometype/$id',
        payload: jsonEncode({
          'token': token,
          'name': name.trim(),
          'detail': detail.trim(),
          'linked_budget_source_ids': selectedIds.toList(),
        }),
      );
      await loadBudgetSources();
      isLoading = false;
      _safeNotify();
      return true;
    } catch (_) {
      error = 'แก้ไขข้อมูลไม่สำเร็จ';
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<bool> deleteIncomeType({
    required String id,
    required String token,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final db = await AppDatabase().database;
      final usageByModule =
          await _localDataSource.countIncomeTypeReferences(id);

      final blockingModules = usageByModule.entries
          .where((entry) => entry.value > 0)
          .map((entry) => '${entry.key} (${entry.value})')
          .toList();

      if (blockingModules.isNotEmpty) {
        error =
            'ไม่สามารถลบได้ เนื่องจากมีรายการอ้างอิงอยู่: ${blockingModules.join(', ')}';
        isLoading = false;
        _safeNotify();
        return false;
      }
      await db.transaction((txn) async {
        await txn.delete(
          'income_type_budget_source_map',
          where: 'refIncomeType = ?',
          whereArgs: [id],
        );
        await txn.delete('income_type', where: 'id = ?', whereArgs: [id]);
      });
      await _syncService.addPendingRequest(
        id: 'income_type_delete_$id',
        method: 'DELETE',
        endpoint: '${baseurl}incometype/$id',
        payload: jsonEncode({'token': token}),
      );
      await loadBudgetSources();
      isLoading = false;
      _safeNotify();
      return true;
    } catch (_) {
      error = 'ลบข้อมูลไม่สำเร็จ';
      isLoading = false;
      _safeNotify();
      return false;
    }
  }
}
