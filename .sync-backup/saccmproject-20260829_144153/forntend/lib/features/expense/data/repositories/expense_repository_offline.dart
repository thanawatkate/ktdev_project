import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:saccm/config.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/error/exceptions.dart';
import 'package:saccm/core/local_data_source/expense_local_data_source.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/features/expense/data/datasources/expense_remote_data_source.dart';
import 'package:saccm/features/license/license_mode.dart';

String _trimStr(Object? v) {
  if (v == null) return '';
  return v.toString().trim();
}

/// รวม refmoneytype / refincometype ให้ตรงกับ backend `assertExpenseSubRowsForReporting`
List<Map<String, dynamic>> _normalizeExpenseSubDataForWrite({
  required List<Map<String, dynamic>> subData,
  String? moneyDomain,
  String? lineRefMoneyTypeFallback,
  String? lineRefIncomeTypeFallback,
}) {
  if (subData.isEmpty) {
    throw ArgumentError.value(
      subData,
      'subData',
      'Expense must include at least one sub line (server requires refmoneytype per row).',
    );
  }
  final needOb = _trimStr(moneyDomain).toLowerCase() == 'off_budget';
  return subData.map((raw) {
    final m = Map<String, dynamic>.from(raw);
    final rmt = _trimStr(m['refmoneytype'] ?? m['refMoneyType']);
    final fbMt = _trimStr(lineRefMoneyTypeFallback);
    if (rmt.isNotEmpty) {
      m['refmoneytype'] = rmt;
    } else if (fbMt.isNotEmpty) {
      m['refmoneytype'] = fbMt;
    }
    if (needOb) {
      final rtc = _trimStr(m['refincometype'] ?? m['refFundCategory']);
      final fbIt = _trimStr(lineRefIncomeTypeFallback);
      if (rtc.isNotEmpty) {
        m['refincometype'] = rtc;
      } else if (fbIt.isNotEmpty) {
        m['refincometype'] = fbIt;
      }
    }
    return m;
  }).toList();
}

void _assertExpenseSubDataServerReady(
  List<Map<String, dynamic>> rows,
  String? moneyDomain,
) {
  final needOb = _trimStr(moneyDomain).toLowerCase() == 'off_budget';
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final rmt = _trimStr(r['refmoneytype'] ?? r['refMoneyType']);
    if (rmt.isEmpty) {
      throw ArgumentError(
        'Expense line ${i + 1}: refmoneytype is required (add to subData or pass lineRefMoneyTypeFallback).',
      );
    }
    if (needOb) {
      final rtc = _trimStr(r['refincometype'] ?? r['refFundCategory']);
      if (rtc.isEmpty) {
        throw ArgumentError(
          'Expense line ${i + 1}: refincometype is required when money_domain is off_budget.',
        );
      }
    }
  }
}

double _parseMoney(Object? value) {
  return double.tryParse(_trimStr(value).replaceAll(',', '')) ?? 0.0;
}

bool _isPostedStatus(String? status) {
  return _trimStr(status).toLowerCase() == 'posted';
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Offline-First Expense Repository
///
///   • READ  → คืนจาก SQLite เสมอ (background pull / ซิงก์เซิร์ฟเวอร์แบบไม่บล็อก UI)
///   • WRITE → บันทึก local ก่อน + queue sync เสมอ
/// ─────────────────────────────────────────────────────────────────────────────
class ExpenseRepository {
  /// ลำดับการเขียน expense บนเครื่องเดียวกัน — ลดโอกาส docno ซ้ำเมื่อกดบันทึกพร้อมกัน
  static Future<void> _writeChain = Future.value();

  static Future<void> _runExpenseWrite(Future<void> Function() fn) async {
    final done = Completer<void>();
    final prev = _writeChain;
    _writeChain = done.future;
    await prev;
    try {
      await fn();
    } finally {
      done.complete();
    }
  }

  final ExpenseLocalDataSource _localDataSource;
  final BudgetSourceLocalDataSource _budgetSourceLocalDataSource;
  final AuditLogLocalDataSource? _auditLogLocalDataSource;
  final NetworkInfoService _networkInfo;
  final SyncService _syncService;
  final ExpenseRemoteDataSource _remoteDataSource;

  ExpenseRepository({
    required ExpenseLocalDataSource localDataSource,
    BudgetSourceLocalDataSource? budgetSourceLocalDataSource,
    AuditLogLocalDataSource? auditLogLocalDataSource,
    required NetworkInfoService networkInfo,
    required SyncService syncService,
    required ExpenseRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _budgetSourceLocalDataSource =
            budgetSourceLocalDataSource ?? BudgetSourceLocalDataSource(),
        _auditLogLocalDataSource = auditLogLocalDataSource,
        _networkInfo = networkInfo,
        _syncService = syncService,
        _remoteDataSource = remoteDataSource;

  // ─── READ: คืน local เสมอ ──────────────────────────────────────────────────

  Future<List<ExpenseModel>> getExpenseList() =>
      _localDataSource.getAllExpenses();

  Future<ExpenseModel?> getExpenseById(String id) =>
      _localDataSource.getExpenseById(id);

  Future<List<Map<String, dynamic>>> getExpenseSubs(String expenseId) =>
      _localDataSource.getExpenseSubsForExpense(expenseId);

  Future<Map<String, dynamic>?> getPayChequeForExpense(String expenseId) =>
      _localDataSource.getPayChequeFirstForExpense(expenseId);

  Future<List<Map<String, dynamic>>> getPayChequesForExpense(
    String expenseId,
  ) =>
      _localDataSource.getPayChequesForExpense(expenseId);

  // ─── WRITE: local-first + queue ────────────────────────────────────────────

  Future<void> createExpense({
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    required String partyName,
    required String refMember,
    required List<Map<String, dynamic>> subData,
    String? refBudgetSource,
    String? refExpenseReq,
    List<Map<String, dynamic>> payCheque = const [],
    String bankAmount = '0',
    String? moneyDomain,
    String? refExpenseReqServerId,
    String? lineRefMoneyTypeFallback,
    String? lineRefIncomeTypeFallback,
    String docStatus = 'posted',
  }) async {
    await _runExpenseWrite(() async {
      final effectiveDocStatus =
          docStatus.trim().isEmpty ? 'posted' : docStatus.trim();
      final normalized = _normalizeExpenseSubDataForWrite(
        subData: subData,
        moneyDomain: moneyDomain,
        lineRefMoneyTypeFallback: lineRefMoneyTypeFallback,
        lineRefIncomeTypeFallback: lineRefIncomeTypeFallback,
      );
      _assertExpenseSubDataServerReady(normalized, moneyDomain);

      final expenseId = '${docno}_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().toIso8601String();

      await _localDataSource.saveExpense(
        ExpenseModel(
          id: expenseId,
          docno: docno,
          docdate: docdate,
          amount: amount,
          detail: detail,
          remark: remark,
          partyName: partyName,
          refBudgetSource: refBudgetSource,
          refExpenseReq: refExpenseReq,
          created: now,
          docStatus: effectiveDocStatus,
          moneyDomain: moneyDomain,
          postedAt: effectiveDocStatus == 'posted' ? now : null,
        ),
        synced: false,
      );

      final rows = normalized;
      for (var i = 0; i < rows.length; i++) {
        final sub = rows[i];
        await _localDataSource.saveExpenseSub(
          id: '${expenseId}_sub$i',
          refExpense: expenseId,
          refExpenseType: sub['refexpensetype']?.toString() ??
              sub['refExpenseType']?.toString(),
          refFundCategory: sub['refincometype']?.toString() ??
              sub['refFundCategory']?.toString(),
          refMoneyType: sub['refmoneytype']?.toString() ??
              sub['refMoneyType']?.toString(),
          amount: sub['amount']?.toString() ?? amount,
          remark: sub['remark']?.toString() ?? remark,
        );
      }

      final refB = _trimStr(refBudgetSource);
      if (_isPostedStatus(effectiveDocStatus) && refB.isNotEmpty) {
        final spend = _parseMoney(amount);
        if (spend > 0) {
          await _budgetSourceLocalDataSource.applyExpenseSpend(
            budgetRowId: refB,
            spendAmount: spend,
          );
        }
      }

      if (payCheque.isNotEmpty) {
        for (var i = 0; i < payCheque.length; i++) {
          final pc = payCheque[i];
          await _localDataSource.savePayCheque(
            id: '${expenseId}_pc$i',
            refExpense: expenseId,
            refChequeAccount: pc['refchequeaccount']?.toString(),
            chequeamount: pc['chequeamount']?.toString() ?? '0',
            chequeno: pc['chequeno']?.toString(),
            remark: pc['remark']?.toString() ?? '',
          );
        }
      }

      await _syncService.addPendingRequest(
        id: 'expense_create_$expenseId',
        method: 'POST',
        endpoint: '${baseurl}expense',
        payload: jsonEncode({
          'token': token,
          'docno': docno,
          'docdate': docdate,
          'amount': amount,
          'detail': detail,
          'remark': remark,
          'partyname': partyName,
          'refmember': refMember,
          'refBudgetSource': refBudgetSource,
          if (_trimStr(refExpenseReqServerId).isNotEmpty)
            'refexpensereq': refExpenseReqServerId,
          'subdata': jsonEncode(normalized),
          'payCheque': payCheque.isEmpty ? '' : jsonEncode(payCheque),
          'bankamount': bankAmount,
          if (moneyDomain != null && moneyDomain.isNotEmpty)
            'money_domain': moneyDomain,
          'doc_status': effectiveDocStatus,
        }),
      );

      await _auditLogLocalDataSource?.logEvent(
        module: 'expense',
        action: 'create',
        entityId: expenseId,
        payload: {
          'docno': docno,
          'amount': amount,
          if (moneyDomain != null) 'money_domain': moneyDomain,
          if (_trimStr(refExpenseReq).isNotEmpty)
            'refExpenseReq': refExpenseReq,
        },
      );

      debugPrint('ExpenseRepository: local save completed, sync queued');
    });
  }

  Future<String> upsertDraftExpense({
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
    String? refBudgetSource,
    String? refExpenseReq,
    List<Map<String, dynamic>> payCheque = const [],
    String bankAmount = '0',
    String? moneyDomain,
    String? refExpenseReqServerId,
    String? lineRefMoneyTypeFallback,
    String? lineRefIncomeTypeFallback,
  }) async {
    String? draftId;
    await _runExpenseWrite(() async {
      final effectiveMoneyDomain =
          _trimStr(moneyDomain).isNotEmpty ? moneyDomain : null;
      final normalized = _normalizeExpenseSubDataForWrite(
        subData: subData,
        moneyDomain: effectiveMoneyDomain,
        lineRefMoneyTypeFallback: lineRefMoneyTypeFallback,
        lineRefIncomeTypeFallback: lineRefIncomeTypeFallback,
      );
      _assertExpenseSubDataServerReady(normalized, effectiveMoneyDomain);

      final expenseId = (localId != null && localId.trim().isNotEmpty)
          ? localId.trim()
          : '${docno}_${DateTime.now().millisecondsSinceEpoch}';
      final existing = await _localDataSource.getExpenseById(expenseId);
      final now = DateTime.now().toIso8601String();

      await _localDataSource.saveExpense(
        ExpenseModel(
          id: expenseId,
          docno: docno,
          docdate: docdate,
          amount: amount,
          detail: detail,
          remark: remark,
          partyName: partyName,
          refBudgetSource: refBudgetSource,
          refExpenseReq: _trimStr(refExpenseReq).isNotEmpty
              ? refExpenseReq
              : existing?.refExpenseReq,
          created: existing?.created ?? now,
          docStatus: 'draft',
          moneyDomain: effectiveMoneyDomain ?? existing?.moneyDomain,
          approvedBy: existing?.approvedBy,
          approvedAt: existing?.approvedAt,
          postedAt: existing?.postedAt,
          changeReason: existing?.changeReason,
        ),
        synced: false,
      );

      await _localDataSource.deleteExpenseSubsForExpense(expenseId);
      for (var i = 0; i < normalized.length; i++) {
        final sub = normalized[i];
        await _localDataSource.saveExpenseSub(
          id: '${expenseId}_sub$i',
          refExpense: expenseId,
          refExpenseType: sub['refexpensetype']?.toString() ??
              sub['refExpenseType']?.toString(),
          refFundCategory: sub['refincometype']?.toString() ??
              sub['refFundCategory']?.toString(),
          refMoneyType: sub['refmoneytype']?.toString() ??
              sub['refMoneyType']?.toString(),
          amount: sub['amount']?.toString() ?? amount,
          remark: sub['remark']?.toString() ?? remark,
        );
      }

      await _localDataSource.deletePayChequesForExpense(expenseId);
      if (payCheque.isNotEmpty) {
        for (var i = 0; i < payCheque.length; i++) {
          final pc = payCheque[i];
          await _localDataSource.savePayCheque(
            id: '${expenseId}_pc$i',
            refExpense: expenseId,
            refChequeAccount: pc['refchequeaccount']?.toString(),
            chequeamount: pc['chequeamount']?.toString() ?? '0',
            chequeno: pc['chequeno']?.toString(),
            remark: pc['remark']?.toString() ?? '',
          );
        }
      }

      await _syncService.addPendingRequest(
        id: 'expense_upsert_$expenseId',
        method: int.tryParse(expenseId) != null ? 'PATCH' : 'POST',
        endpoint: int.tryParse(expenseId) != null
            ? '${baseurl}expense/$expenseId'
            : '${baseurl}expense',
        payload: jsonEncode({
          'token': token,
          'docno': docno,
          'docdate': docdate,
          'amount': amount,
          'detail': detail,
          'remark': remark,
          'partyname': partyName,
          'refmember': refMember,
          'refBudgetSource': refBudgetSource,
          if (_trimStr(refExpenseReqServerId).isNotEmpty)
            'refexpensereq': refExpenseReqServerId,
          'subdata': jsonEncode(normalized),
          'payCheque': payCheque.isEmpty ? '' : jsonEncode(payCheque),
          'bankamount': bankAmount,
          if (_trimStr(effectiveMoneyDomain).isNotEmpty)
            'money_domain': effectiveMoneyDomain,
          'doc_status': 'draft',
        }),
        silent: true,
      );
      draftId = expenseId;
    });
    return draftId!;
  }

  /// อัปเดตข้อมูล expense ใน local แล้ว queue sync payload ล่าสุดขึ้น server
  Future<void> updateExpense({
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
    String? refBudgetSource,
    String? refExpenseReq,
    List<Map<String, dynamic>> payCheque = const [],
    String bankAmount = '0',
    String? moneyDomain,
    String? changeReason,
    String? refExpenseReqServerId,
    String? lineRefMoneyTypeFallback,
    String? lineRefIncomeTypeFallback,
    String? docStatus,
  }) async {
    await _runExpenseWrite(() async {
      final existing = await _localDataSource.getExpenseById(localId);
      final effectiveMoneyDomain = _trimStr(moneyDomain).isNotEmpty
          ? moneyDomain
          : existing?.moneyDomain;
      final effectiveDocStatus = docStatus?.trim().isNotEmpty == true
          ? docStatus!.trim()
          : (existing?.docStatus ?? 'posted');
      final wasPosted = _isPostedStatus(existing?.docStatus);
      final willBePosted = _isPostedStatus(effectiveDocStatus);
      final normalized = _normalizeExpenseSubDataForWrite(
        subData: subData,
        moneyDomain: effectiveMoneyDomain,
        lineRefMoneyTypeFallback: lineRefMoneyTypeFallback,
        lineRefIncomeTypeFallback: lineRefIncomeTypeFallback,
      );
      _assertExpenseSubDataServerReady(normalized, effectiveMoneyDomain);

      await _localDataSource.saveExpense(
        ExpenseModel(
          id: localId,
          docno: docno,
          docdate: docdate,
          amount: amount,
          detail: detail,
          remark: remark,
          partyName: partyName,
          refBudgetSource: refBudgetSource,
          refExpenseReq: _trimStr(refExpenseReq).isNotEmpty
              ? refExpenseReq
              : existing?.refExpenseReq,
          created: existing?.created ?? DateTime.now().toIso8601String(),
          docStatus: effectiveDocStatus,
          moneyDomain: moneyDomain ?? existing?.moneyDomain,
          approvedBy: existing?.approvedBy,
          approvedAt: existing?.approvedAt,
          postedAt: effectiveDocStatus == 'posted'
              ? (existing?.postedAt ?? DateTime.now().toIso8601String())
              : existing?.postedAt,
          changeReason: (changeReason?.trim().isNotEmpty ?? false)
              ? changeReason!.trim()
              : existing?.changeReason,
        ),
        synced: false,
      );

      await _localDataSource.deleteExpenseSubsForExpense(localId);
      final rows = normalized;
      for (var i = 0; i < rows.length; i++) {
        final sub = rows[i];
        await _localDataSource.saveExpenseSub(
          id: '${localId}_sub$i',
          refExpense: localId,
          refExpenseType: sub['refexpensetype']?.toString() ??
              sub['refExpenseType']?.toString(),
          refFundCategory: sub['refincometype']?.toString() ??
              sub['refFundCategory']?.toString(),
          refMoneyType: sub['refmoneytype']?.toString() ??
              sub['refMoneyType']?.toString(),
          amount: sub['amount']?.toString() ?? amount,
          remark: sub['remark']?.toString() ?? remark,
        );
      }

      await _localDataSource.deletePayChequesForExpense(localId);
      if (payCheque.isNotEmpty) {
        for (var i = 0; i < payCheque.length; i++) {
          final pc = payCheque[i];
          await _localDataSource.savePayCheque(
            id: '${localId}_pc$i',
            refExpense: localId,
            refChequeAccount: pc['refchequeaccount']?.toString(),
            chequeamount: pc['chequeamount']?.toString() ?? '0',
            chequeno: pc['chequeno']?.toString(),
            remark: pc['remark']?.toString() ?? '',
          );
        }
      }

      final oldRefB = _trimStr(existing?.refBudgetSource);
      final newRefB = _trimStr(refBudgetSource);
      final oldSpend = _parseMoney(existing?.amount);
      final newSpend = _parseMoney(amount);
      if (!wasPosted && willBePosted && newRefB.isNotEmpty) {
        if (newSpend > 0) {
          await _budgetSourceLocalDataSource.applyExpenseSpend(
            budgetRowId: newRefB,
            spendAmount: newSpend,
          );
        }
      } else if (wasPosted && !willBePosted && oldRefB.isNotEmpty) {
        if (oldSpend > 0) {
          await _budgetSourceLocalDataSource.adjustPostedExpenseUsedAmount(
            budgetRowId: oldRefB,
            amountDelta: -oldSpend,
          );
        }
      } else if (wasPosted && willBePosted) {
        if (oldRefB.isNotEmpty && oldRefB == newRefB) {
          await _budgetSourceLocalDataSource.adjustPostedExpenseUsedAmount(
            budgetRowId: oldRefB,
            amountDelta: newSpend - oldSpend,
          );
        } else {
          if (oldRefB.isNotEmpty && oldSpend > 0) {
            await _budgetSourceLocalDataSource.adjustPostedExpenseUsedAmount(
              budgetRowId: oldRefB,
              amountDelta: -oldSpend,
            );
          }
          if (newRefB.isNotEmpty && newSpend > 0) {
            await _budgetSourceLocalDataSource.adjustPostedExpenseUsedAmount(
              budgetRowId: newRefB,
              amountDelta: newSpend,
            );
          }
        }
      }

      await _syncService.addPendingRequest(
        id: 'expense_upsert_$localId',
        method: int.tryParse(localId) != null ? 'PATCH' : 'POST',
        endpoint: int.tryParse(localId) != null
            ? '${baseurl}expense/$localId'
            : '${baseurl}expense',
        payload: jsonEncode({
          'token': token,
          'docno': docno,
          'docdate': docdate,
          'amount': amount,
          'detail': detail,
          'remark': remark,
          'partyname': partyName,
          'refmember': refMember,
          'refBudgetSource': refBudgetSource,
          if (_trimStr(refExpenseReqServerId).isNotEmpty)
            'refexpensereq': refExpenseReqServerId,
          'subdata': jsonEncode(normalized),
          'payCheque': payCheque.isEmpty ? '' : jsonEncode(payCheque),
          'bankamount': bankAmount,
          if (_trimStr(effectiveMoneyDomain).isNotEmpty)
            'money_domain': effectiveMoneyDomain,
          'doc_status': effectiveDocStatus,
          if (changeReason != null && changeReason.isNotEmpty)
            'change_reason': changeReason,
        }),
      );

      await _auditLogLocalDataSource?.logEvent(
        module: 'expense',
        action: 'update',
        entityId: localId,
        payload: {
          'docno': docno,
          'amount': amount,
          if (changeReason != null && changeReason.isNotEmpty)
            'change_reason': changeReason,
        },
      );
    });
  }

  Future<void> deleteExpense({
    required String localId,
    required String token,
  }) async {
    await _runExpenseWrite(() async {
      final existing = await _localDataSource.getExpenseById(localId);
      if (existing == null) return;
      final status = (existing.docStatus ?? '').trim().toLowerCase();
      if (status == 'posted') {
        throw StateError('เอกสารถูกโพสต์แล้ว ไม่อนุญาตให้ลบ');
      }

      await _syncService.cancelPendingRequest('expense_create_$localId');
      await _syncService.cancelPendingRequest('expense_upsert_$localId');
      await _localDataSource.deleteExpense(localId);

      if (existing.synced) {
        await _syncService.addPendingRequest(
          id: 'expense_delete_$localId',
          method: 'DELETE',
          endpoint: '${baseurl}expense/$localId',
          payload: jsonEncode({
            'token': token,
            'docno': existing.docno,
          }),
        );
      }

      await _auditLogLocalDataSource?.logEvent(
        module: 'expense',
        action: 'delete',
        entityId: localId,
        payload: {'docno': existing.docno},
      );
    });
  }

  // ─── BACKGROUND PULL: อัปเดต local cache จาก server ──────────────────────

  /// ดึง expense list จาก server แล้วบันทึก local cache
  /// เรียกแบบ fire-and-forget จาก Provider — ไม่ throw exception
  static const int _backupListPageSizeHint = 100;
  static const int _backupMaxPages = 400;

  /// ดึงรายจ่ายทุกหน้าจากเซิร์ฟเวอร์แล้วเขียนลง local (ใช้ก่อนเทียบ digest)
  Future<void> pullAllExpensePagesForBackup() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    final merged = <ExpenseModel>[];
    for (var page = 1; page <= _backupMaxPages; page++) {
      List<ExpenseModel> chunk;
      try {
        chunk = await _remoteDataSource.getExpenseList(page: page);
      } catch (_) {
        break;
      }
      if (chunk.isEmpty) break;
      merged.addAll(chunk);
      if (chunk.length < _backupListPageSizeHint) break;
    }
    if (merged.isNotEmpty) {
      await _localDataSource.saveExpenses(merged);
      debugPrint(
        'ExpenseRepository: backup pull merged ${merged.length} expense rows',
      );
    }
  }

  Future<bool> backgroundPull() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return false;
    }
    try {
      final remote = await _remoteDataSource.getExpenseList();
      await _localDataSource.saveExpenses(remote);
      debugPrint(
          'ExpenseRepository: background pull success (${remote.length} items)');
      return true;
    } on ServerException catch (e) {
      // Keep local-first flow intact; suppress noisy HTML payloads in logs.
      debugPrint('ExpenseRepository: background pull skipped: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('ExpenseRepository: background pull failed: $e');
      return false;
    }
  }

  Future<List<String>> getPartyNames() async {
    try {
      final db = _localDataSource.db;
      final fromParty = await db.rawQuery('''
        SELECT name FROM party
        WHERE LOWER(role) IN ('receiver', 'both')
        AND (isactive = 1 OR isactive = '1')
        AND TRIM(name) <> ''
        ORDER BY name COLLATE NOCASE ASC
      ''');
      final names = <String>{};
      for (final r in fromParty) {
        final n = r['name']?.toString().trim() ?? '';
        if (n.isNotEmpty) names.add(n);
      }
      final expRows = await db.rawQuery('''
        SELECT DISTINCT partyName AS name
        FROM expense
        WHERE partyName IS NOT NULL AND TRIM(partyName) <> ''
      ''');
      for (final r in expRows) {
        final n = r['name']?.toString().trim() ?? '';
        if (n.isEmpty) continue;
        if (names.any((e) => e.toLowerCase() == n.toLowerCase())) continue;
        names.add(n);
      }
      final out = names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return out;
    } catch (_) {
      return [];
    }
  }

  /// แถวผู้รับ/ผู้เกี่ยวข้องสำหรับชีตเลือก (อ่านจาก `party` + ชื่อจาก expense)
  Future<List<Map<String, dynamic>>> getPartyRowsForPickerLocal() async {
    try {
      final db = _localDataSource.db;
      final rows = await db.query('party', orderBy: 'name COLLATE NOCASE ASC');
      final out = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final e in rows) {
        final name = (e['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        seen.add(name.toLowerCase());
        final active = e['isactive'] == 1 ||
            e['isactive'] == true ||
            e['isactive']?.toString() == '1';
        out.add(<String, dynamic>{
          'id': e['id'],
          'name': name,
          'role': (e['role'] ?? 'both').toString(),
          'isactive': active,
        });
      }
      final expRows = await db.rawQuery('''
        SELECT DISTINCT partyName AS name FROM expense
        WHERE partyName IS NOT NULL AND TRIM(partyName) <> ''
      ''');
      for (final r in expRows) {
        final n = (r['name'] ?? '').toString().trim();
        if (n.isEmpty || seen.contains(n.toLowerCase())) continue;
        seen.add(n.toLowerCase());
        out.add(<String, dynamic>{
          'id': n,
          'name': n,
          'role': 'both',
          'isactive': true,
        });
      }
      out.sort(
        (a, b) => (a['name'] as String)
            .toLowerCase()
            .compareTo((b['name'] as String).toLowerCase()),
      );
      return out;
    } catch (_) {
      return [];
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> clearLocalCache() => _localDataSource.clearAllExpenses();

  Future<bool> get isConnected => _networkInfo.isConnected;

  Stream<bool> get onConnectivityChanged => _networkInfo.onConnectivityChanged;
}
