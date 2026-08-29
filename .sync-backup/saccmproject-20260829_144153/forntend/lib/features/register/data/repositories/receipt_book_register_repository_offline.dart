import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:saccm/config.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/doc_group_local_data_source.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/session_token_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/features/register/data/datasources/register_remote_data_source.dart';

class ReceiptBookSaveResult {
  const ReceiptBookSaveResult({
    required this.id,
    required this.synced,
  });

  final String id;
  final bool synced;
}

typedef ReceiptBookWriteResult = ReceiptBookSaveResult;

/// Offline-first repository for receipt-book register.
///
/// UI should call this instead of talking to remote/sync services directly.
class ReceiptBookRegisterRepositoryOffline {
  ReceiptBookRegisterRepositoryOffline({
    required RegisterRemoteDataSource remote,
    required RegisterLocalDataSource local,
    required DocGroupLocalDataSource docGroupLocal,
    required NetworkInfoService networkInfo,
    required SyncService syncService,
  })  : _local = local,
        _docGroupLocal = docGroupLocal,
        _syncService = syncService;

  final RegisterLocalDataSource _local;
  final DocGroupLocalDataSource _docGroupLocal;
  final SyncService _syncService;

  Future<List<Map<String, dynamic>>> listReceiptBooks({
    required String fiscalYear,
  }) async {
    return _local.listReceiptBooks(fiscalYear: fiscalYear);
  }

  Future<String> suggestNextBookNo({
    required String fiscalYear,
    required String receiptType,
  }) async {
    final config = await _docGroupLocal.getReceiptBookConfig();
    final rows = await _local.listReceiptBooks(fiscalYear: fiscalYear);
    const runMarker = '__RUN__';
    final baseWithMarker = _resolveDocGroupFormat(
      format: config.docNoFormat,
      runGroup: config.runGroup,
      fiscalYear: fiscalYear,
      runText: runMarker,
    );
    final escaped =
        RegExp.escape(baseWithMarker).replaceAll(runMarker, r'(\d+)');
    final bookNoPattern = RegExp('^$escaped\$');
    var maxNo = 0;

    for (final row in rows) {
      if (row['receipt_type']?.toString() != receiptType) continue;
      final bookNo = row['book_no']?.toString().trim() ?? '';
      final match = bookNoPattern.firstMatch(bookNo);
      if (match == null) continue;

      final n = int.tryParse(match.group(1) ?? '');
      if (n == null || n <= maxNo) continue;
      maxNo = n;
    }

    return _resolveDocGroupFormat(
      format: config.docNoFormat,
      runGroup: config.runGroup,
      fiscalYear: fiscalYear,
      runText:
          (maxNo + 1).toString().padLeft(_runWidth(config.docNoFormat), '0'),
    );
  }

  Future<ReceiptBookSaveResult> createReceiptBook(
    Map<String, dynamic> body,
  ) async {
    _assertValidReceiptRange(body);
    if (await _hasDuplicateBookNo(body)) {
      throw Exception(TransactionUiText.registerReceiptBookDuplicate);
    }

    final token = await SessionTokenService.readToken();
    final hasServerToken = SessionTokenService.isServerJwt(token);
    var localId = 'local_receipt_book_${DateTime.now().millisecondsSinceEpoch}';

    if (hasServerToken && await LicenseMode.canSyncOnline()) {
      await _queueCreate(localId: localId, token: token, body: body);
    }

    await _local.upsertReceiptBookLocal({
      'id': localId,
      ...body,
      'status': 'available',
      'synced': 0,
    });

    return ReceiptBookSaveResult(id: localId, synced: false);
  }

  Future<ReceiptBookWriteResult> updateReceiptBook({
    required String id,
    required Map<String, dynamic> body,
    required bool coreFieldsLocked,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception(TransactionUiText.requestedDataNotFound);
    }
    _assertValidReceiptRange(body);
    if (!coreFieldsLocked && await _hasDuplicateBookNo(body, excludeId: id)) {
      throw Exception(TransactionUiText.registerReceiptBookDuplicate);
    }

    final token = await SessionTokenService.readToken();
    final hasServerToken = SessionTokenService.isServerJwt(token);
    final isLocalOnly = normalizedId.startsWith('local_');

    if (hasServerToken && await LicenseMode.canSyncOnline()) {
      if (!isLocalOnly) {
        await _queuePatch(id: normalizedId, token: token, body: body);
      } else {
        await _syncService.cancelPendingRequest(
          'receipt_book_create_$normalizedId',
        );
        await _queueCreate(localId: normalizedId, token: token, body: body);
      }
    }

    await _local.upsertReceiptBookLocal({
      'id': normalizedId,
      ...body,
      'status': body['status']?.toString() ?? 'available',
      'synced': 0,
    });

    return ReceiptBookWriteResult(id: normalizedId, synced: false);
  }

  Future<ReceiptBookWriteResult> deleteReceiptBook(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception(TransactionUiText.requestedDataNotFound);
    }

    final usedCount = await _local.countReceiptBookUsage(normalizedId);
    if (usedCount > 0) {
      throw Exception(TransactionUiText.registerReceiptBookDeleteBlocked);
    }

    final token = await SessionTokenService.readToken();
    final hasServerToken = SessionTokenService.isServerJwt(token);
    final isLocalOnly = normalizedId.startsWith('local_');

    await _syncService.cancelPendingRequest('receipt_book_patch_$normalizedId');

    if (isLocalOnly) {
      await _syncService.cancelPendingRequest(
        'receipt_book_create_$normalizedId',
      );
      await _local.deleteReceiptBookLocal(normalizedId);
      return ReceiptBookWriteResult(id: normalizedId, synced: false);
    }

    if (hasServerToken && await LicenseMode.canSyncOnline()) {
      await _queueDelete(id: normalizedId, token: token);
    }

    await _local.deleteReceiptBookLocal(normalizedId);
    return ReceiptBookWriteResult(id: normalizedId, synced: false);
  }

  Future<void> applyCreateSyncSuccess(
    String localId,
    Map<String, dynamic> response,
  ) async {
    final serverId = response['id'] ??
        response['lastid'] ??
        response['lastId'] ??
        response['insertId'];
    await _local.markReceiptBookSynced(
      localId,
      serverId: serverId?.toString(),
    );
  }

  Future<bool> _hasDuplicateBookNo(
    Map<String, dynamic> body, {
    String? excludeId,
  }) async {
    final rows = await _local.listReceiptBooks(
      fiscalYear: body['fiscal_year']?.toString(),
    );
    return rows.any((row) =>
        row['id']?.toString() != excludeId &&
        row['fiscal_year']?.toString() == body['fiscal_year']?.toString() &&
        row['receipt_type']?.toString() == body['receipt_type']?.toString() &&
        row['book_no']?.toString().trim() ==
            body['book_no']?.toString().trim());
  }

  static String? validateReceiptRange({
    required String startNo,
    required String endNo,
  }) {
    final startDigits = _digitsOnly(startNo);
    final endDigits = _digitsOnly(endNo);
    if (startDigits.isEmpty || endDigits.isEmpty) {
      return TransactionUiText.registerReceiptBookRangeDigitsRequired;
    }

    final start = int.tryParse(startDigits);
    final end = int.tryParse(endDigits);
    if (start == null ||
        end == null ||
        end < start ||
        endDigits.length < startDigits.length) {
      return TransactionUiText.registerReceiptBookRangeInvalid;
    }
    return null;
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _assertValidReceiptRange(Map<String, dynamic> body) {
    final message = validateReceiptRange(
      startNo: body['start_no']?.toString() ?? '',
      endNo: body['end_no']?.toString() ?? '',
    );
    if (message != null) throw Exception(message);
  }

  int _runWidth(String format) {
    final match = RegExp(r'\{RUN(\d*)\}').firstMatch(format);
    if (match == null) return 3;
    final rawWidth = match.group(1) ?? '';
    return rawWidth.isEmpty ? 3 : int.tryParse(rawWidth) ?? 3;
  }

  String _resolveDocGroupFormat({
    required String format,
    required String runGroup,
    required String fiscalYear,
    required String runText,
  }) {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');

    var out = format
        .replaceAll('{RUNGROUP}', runGroup)
        .replaceAll('{RG}', runGroup)
        .replaceAll('{FISCAL_YEAR}', fiscalYear)
        .replaceAll('{FY}', fiscalYear)
        .replaceAll('{YYYY}', yyyy)
        .replaceAll('{YY}', yy)
        .replaceAll('{MM}', mm)
        .replaceAll('{DD}', dd);
    out = out.replaceAll(RegExp(r'\{RUN\d*\}'), runText);
    if (!out.contains(runText)) return '$out-$runText';
    return out;
  }

  Future<void> _queueCreate({
    required String localId,
    required String? token,
    required Map<String, dynamic> body,
  }) async {
    try {
      await _syncService.addPendingRequest(
        id: 'receipt_book_create_$localId',
        method: 'POST',
        endpoint: '${baseurl}register/receipt-books',
        payload: jsonEncode({
          ...body,
          'token': token,
        }),
        silent: true,
      );
    } catch (e) {
      debugPrint('ReceiptBookRegister: queue create failed: $e');
    }
  }

  Future<void> _queuePatch({
    required String id,
    required String? token,
    required Map<String, dynamic> body,
  }) async {
    try {
      await _syncService.addPendingRequest(
        id: 'receipt_book_patch_$id',
        method: 'PATCH',
        endpoint: '${baseurl}register/receipt-books/$id',
        payload: jsonEncode({
          ...body,
          'token': token,
        }),
        silent: true,
      );
    } catch (e) {
      debugPrint('ReceiptBookRegister: queue patch failed: $e');
    }
  }

  Future<void> _queueDelete({
    required String id,
    required String? token,
  }) async {
    try {
      await _syncService.addPendingRequest(
        id: 'receipt_book_delete_$id',
        method: 'DELETE',
        endpoint: '${baseurl}register/receipt-books/$id',
        payload: jsonEncode({'token': token}),
        silent: true,
      );
    } catch (e) {
      debugPrint('ReceiptBookRegister: queue delete failed: $e');
    }
  }
}
