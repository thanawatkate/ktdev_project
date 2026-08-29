import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:saccm/config.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ปิดวัน / แจ้งเตือน / บันทึกเหตุผลงบเทียบยอดธนาคาร
class FinanceComplianceService {
  FinanceComplianceService({Dio? dio, SyncService? syncService})
      : _dio = dio ?? Dio(),
        _syncService = syncService;

  final Dio _dio;
  final SyncService? _syncService;

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<Map<String, dynamic>>> fetchAlerts({String? date}) async {
    try {
      final res = await _dio.get(
        '${baseurl}finance-compliance/alerts',
        queryParameters: {if (date != null) 'date': date},
      );
      final list = res.data?['data']?['alerts'];
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> isDayClosed(String date) async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'daily_closing',
      where: 'close_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String?> closeDay({
    required String date,
    String? note,
    int? userId,
    Map<String, dynamic>? snapshot,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return 'ไม่พบ token — ล็อกอินใหม่';
    }
    final db = await AppDatabase().database;
    final existing = await db.query(
      'daily_closing',
      where: 'close_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return 'วันนี้ปิดวันแล้ว';
    }

    final localSnapshot = <String, dynamic>{
      'close_date': date,
      if (snapshot != null) ...snapshot,
    };
    await db.insert(
      'daily_closing',
      {
        'close_date': date,
        'snapshot_json': jsonEncode(localSnapshot),
        'closed_by': userId?.toString(),
        'note': note,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final payload = {
      'token': token,
      'close_date': date,
      if (note != null && note.isNotEmpty) 'note': note,
      if (userId != null) 'refuser': userId,
      'snapshot_json': localSnapshot,
    };

    await _syncService?.addPendingRequest(
      id: 'finance_daily_close_$date',
      method: 'POST',
      endpoint: '${baseurl}finance-compliance/close-day',
      payload: jsonEncode(payload),
    );
    return null;
  }

  Future<List<Map<String, dynamic>>> listRecentClosings(
      {int limit = 10}) async {
    final db = await AppDatabase().database;
    final localRows = await db.query(
      'daily_closing',
      orderBy: 'close_date DESC',
      limit: limit,
    );
    return localRows;
  }

  Future<String?> saveReconciliationNote({
    required String asOfDate,
    required String reasonCode,
    required double amount,
    String? note,
    String? refBankAccount,
    int? userId,
  }) async {
    final token = await _token();
    final db = await AppDatabase().database;
    final localId = await db.insert('bank_reconciliation_adjustment', {
      'as_of_date': asOfDate,
      'ref_bankaccount': refBankAccount,
      'reason_code': reasonCode,
      'amount': amount,
      'note': note,
      'synced': 0,
    });

    if (token == null || token.isEmpty) return null;
    final payload = {
      'token': token,
      'as_of_date': asOfDate,
      'reason_code': reasonCode,
      'amount': amount,
      if (note != null) 'note': note,
      if (refBankAccount != null) 'ref_bankaccount': refBankAccount,
      if (userId != null) 'refuser': userId,
    };
    await _syncService?.addPendingRequest(
      id: 'bank_recon_note_$localId',
      method: 'POST',
      endpoint: '${baseurl}finance-compliance/reconciliation-note',
      payload: jsonEncode(payload),
    );
    return null;
  }

  Future<List<Map<String, dynamic>>> listReconciliationNotes(
      String date) async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'bank_reconciliation_adjustment',
      where: 'as_of_date = ?',
      whereArgs: [date],
      orderBy: 'id DESC',
    );
    return rows;
  }
}
