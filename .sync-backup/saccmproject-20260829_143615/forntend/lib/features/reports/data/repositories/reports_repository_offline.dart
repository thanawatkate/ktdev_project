import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:saccm/config.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/local_data_source/report_materialized_store.dart';
import 'package:saccm/core/local_data_source/reports_local_data_source.dart';
import 'package:saccm/core/services/session_token_service.dart';

/// Reports repository (local-first).
///
/// - UI reads cached bundle from SQLite first.
/// - Remote fetch runs separately and refreshes cache.
class ReportsRepository {
  ReportsRepository({
    Dio? dio,
    ReportsLocalDataSource? localDataSource,
  })  : _dio = dio ?? Dio(),
        _localDataSource = localDataSource ?? ReportsLocalDataSource();

  final Dio _dio;
  final ReportsLocalDataSource _localDataSource;

  Future<Options?> _authOptions() async {
    final token = await SessionTokenService.readToken();
    if (!SessionTokenService.isServerJwt(token)) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>?> loadCachedBundle(String fiscalYear) async {
    final db = await AppDatabase().database;
    return ReportMaterializedStore.loadBundle(db, fiscalYear);
  }

  /// Cache-first display path (fast materialized rows, no heavy recompute).
  Future<Map<String, dynamic>?> loadDisplayBundle(String fiscalYear) async {
    return loadCachedBundle(fiscalYear);
  }

  Future<Map<String, dynamic>> loadLocalBundle(String fiscalYear) async {
    return _localDataSource.loadBundle(fiscalYear);
  }

  Future<void> syncAndLoadBundle(String fiscalYear) async {
    final options = await _authOptions();
    final results = await Future.wait([
      _dio.get(
        '${baseurl}reports/summary',
        queryParameters: {'fiscal_year': fiscalYear},
        options: options,
      ),
      _dio.get(
        '${baseurl}reports/income-by-month',
        queryParameters: {'fiscal_year': fiscalYear},
        options: options,
      ),
      _dio.get(
        '${baseurl}reports/expense-by-month',
        queryParameters: {'fiscal_year': fiscalYear},
        options: options,
      ),
      _dio.get(
        '${baseurl}reports/by-budget-source',
        queryParameters: {'fiscal_year': fiscalYear},
        options: options,
      ),
      _dio.get(
        '${baseurl}reports/trial-balance',
        queryParameters: {'fiscal_year': fiscalYear},
        options: options,
      ),
      _dio.get(
        '${baseurl}reports/budget-remaining',
        queryParameters: {'fiscal_year': fiscalYear},
        options: options,
      ),
      _dio.get(
        '${baseurl}reports/annual-summary',
        queryParameters: {'fiscal_year': fiscalYear},
        options: options,
      ),
    ]);

    final bundle = <String, dynamic>{
      'summary': results[0].data['data'],
      'incomeByMonth': results[1].data['data'] ?? [],
      'expenseByMonth': results[2].data['data'] ?? [],
      'budgetData': results[3].data['data'] ?? [],
      'trialBalance': results[4].data['data'],
      'budgetRemaining': results[5].data['data'] ?? [],
      'annualSummary': results[6].data['data'],
    };

    final db = await AppDatabase().database;
    await ReportMaterializedStore.replaceBundle(db, fiscalYear, bundle);
  }

  Future<Map<String, dynamic>?> fetchDailyBalance(String date) async {
    final response = await _dio.get(
      '${baseurl}reports/daily-balance',
      queryParameters: {'date': date},
      options: await _authOptions(),
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>?> loadCachedDailyBalance(String date) async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'report_daily_balance_cache',
      where: 'report_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['payload_json']?.toString() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  /// คำนวณเงินคงเหลือประจำวันจาก SQLite (fallback ออฟไลน์)
  Future<Map<String, dynamic>> loadDailyBalanceLocal(String date) async {
    return _localDataSource.loadDailyBalance(date);
  }

  Future<void> syncDailyBalance(String date) async {
    final data = await fetchDailyBalance(date);
    if (data == null) throw StateError('Daily balance report returned no data');
    final db = await AppDatabase().database;
    await db.insert(
      'report_daily_balance_cache',
      {
        'report_date': date,
        'payload_json': jsonEncode(data),
        'fetched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> fetchBankReconciliation(String date) async {
    final response = await _dio.get(
      '${baseurl}reports/bank-reconciliation',
      queryParameters: {'date': date},
      options: await _authOptions(),
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>?> loadCachedBankReconciliation(
      String date) async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'report_bank_reconciliation_cache',
      where: 'report_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['payload_json']?.toString() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> loadBankReconciliationLocal(String date) async {
    return _localDataSource.loadBankReconciliation(date);
  }

  Future<void> syncBankReconciliation(String date) async {
    final data = await fetchBankReconciliation(date);
    if (data == null) {
      throw StateError('Bank reconciliation report returned no data');
    }
    final db = await AppDatabase().database;
    await db.insert(
      'report_bank_reconciliation_cache',
      {
        'report_date': date,
        'payload_json': jsonEncode(data),
        'fetched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> fetchDailyCashSummary(String date) async {
    final response = await _dio.get(
      '${baseurl}reports/daily-cash-summary',
      queryParameters: {'date': date},
      options: await _authOptions(),
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>?> loadCachedDailyCashSummary(String date) async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'report_daily_cash_summary_cache',
      where: 'report_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['payload_json']?.toString() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> syncDailyCashSummary(String date) async {
    final data = await fetchDailyCashSummary(date);
    if (data == null) {
      throw StateError('Daily cash summary report returned no data');
    }
    final db = await AppDatabase().database;
    await db.insert(
      'report_daily_cash_summary_cache',
      {
        'report_date': date,
        'payload_json': jsonEncode(data),
        'fetched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static String outstandingChequesCacheKey(String date, int? fiscalYear) {
    final day =
        date.trim().length >= 10 ? date.trim().substring(0, 10) : date.trim();
    return '$day|${fiscalYear ?? ''}';
  }

  Future<Map<String, dynamic>?> fetchOutstandingCheques({
    required String date,
    int? fiscalYear,
  }) async {
    final response = await _dio.get(
      '${baseurl}reports/outstanding-cheques',
      queryParameters: {
        'date': date,
        if (fiscalYear != null) 'fiscal_year': fiscalYear,
      },
      options: await _authOptions(),
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) {
      return _normalizeOutstandingChequesPayload(data);
    }
    if (data is Map) {
      return _normalizeOutstandingChequesPayload(
          Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadCachedOutstandingCheques({
    required String date,
    int? fiscalYear,
  }) async {
    final key = outstandingChequesCacheKey(date, fiscalYear);
    final db = await AppDatabase().database;
    final rows = await db.query(
      'report_outstanding_cheques_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['payload_json']?.toString() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _normalizeOutstandingChequesPayload(decoded);
      }
      if (decoded is Map) {
        return _normalizeOutstandingChequesPayload(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> syncOutstandingCheques({
    required String date,
    int? fiscalYear,
  }) async {
    final data = await fetchOutstandingCheques(
      date: date,
      fiscalYear: fiscalYear,
    );
    if (data == null) {
      throw StateError('Outstanding cheques report returned no data');
    }
    final db = await AppDatabase().database;
    await db.insert(
      'report_outstanding_cheques_cache',
      {
        'cache_key': outstandingChequesCacheKey(date, fiscalYear),
        'payload_json': jsonEncode(data),
        'fetched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// เช็คค้างจาก SQLite (fallback เมื่อ API ไม่พร้อม)
  Future<Map<String, dynamic>> loadOutstandingChequesLocal({
    required String date,
    int? fiscalYear,
  }) async {
    return _localDataSource.loadOutstandingCheques(
      date: date,
      fiscalYear: fiscalYear,
    );
  }

  Map<String, dynamic> _normalizeOutstandingChequesPayload(
    Map<String, dynamic> data,
  ) {
    final rawRows = data['rows'];
    final rows = rawRows is List
        ? rawRows
            .map((e) => _normalizeOutstandingChequeRow(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList()
        : <Map<String, dynamic>>[];

    final totalRaw = data['total_outstanding'];
    final total = totalRaw != null
        ? (double.tryParse(totalRaw.toString()) ??
            _sumOutstandingChequeRows(rows))
        : _sumOutstandingChequeRows(rows);

    return {
      ...data,
      'rows': rows,
      'total_outstanding': total,
      'count': data['count'] ?? rows.length,
    };
  }

  Map<String, dynamic> _normalizeOutstandingChequeRow(
      Map<String, dynamic> row) {
    if (row['amount'] == null && row['chequeamount'] != null) {
      row['amount'] = row['chequeamount'];
    }
    return row;
  }

  double _sumOutstandingChequeRows(List<Map<String, dynamic>> rows) {
    return rows.fold<double>(
      0,
      (s, r) =>
          s +
          (double.tryParse(
                (r['amount'] ?? r['chequeamount'])?.toString() ?? '0',
              ) ??
              0),
    );
  }

  /// สรุปเงินสดรายวันจาก SQLite — ยอดยกมา / รับแยกสด-โอน / จ่ายสด / ยกไป
  /// คำนวณเฉพาะช่องทางเงินสด (ไม่รวมธนาคารและส่วนราชการผู้เบิก)
  Future<Map<String, dynamic>> loadDailyCashSummaryLocal(String isoDate) async {
    return _localDataSource.loadDailyCashSummary(isoDate);
  }

  void dispose() {
    _dio.close(force: true);
  }
}
