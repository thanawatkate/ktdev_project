import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

/// Remote data source สำหรับโมดูลทะเบียนคุม
/// - off-budget ledger (ทะเบียนคุมเงินนอกงบประมาณ 13 หมวด)
/// - evidence / voucher / cheque / loan registers
/// - receipt book + receipt issue
/// - deposit guarantee (เงินประกันสัญญา / เงินภาษีหัก ณ ที่จ่าย)
class RegisterRemoteDataSource {
  RegisterRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  Future<List<Map<String, dynamic>>> listOffBudgetCategories() async {
    final r = await _dio.get('${baseurl}register/offbudget/categories');
    final data = (r.data?['data'] as List?) ?? const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getOffBudgetLedger({
    required int fiscalYearBuddhist,
    int? categoryId,
    String? code,
  }) async {
    final r = await _dio.get(
      '${baseurl}register/offbudget/ledger',
      queryParameters: {
        'fiscal_year': fiscalYearBuddhist,
        if (categoryId != null) 'category_id': categoryId,
        if (code != null && code.isNotEmpty) 'code': code,
      },
    );
    final data = r.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getEvidenceRegister({int? fiscalYear}) =>
      _genericList('register/evidence', fiscalYear);

  Future<List<Map<String, dynamic>>> getVoucherRegister({int? fiscalYear}) =>
      _genericList('register/voucher', fiscalYear);

  Future<List<Map<String, dynamic>>> getChequeRegister({int? fiscalYear}) =>
      _genericList('register/cheque', fiscalYear);

  Future<List<Map<String, dynamic>>> getLoanRegister({int? fiscalYear}) =>
      _genericList('register/loan', fiscalYear);

  Future<Map<String, dynamic>> getCurrentAccountRegister({
    required int fiscalYearBuddhist,
  }) async {
    final r = await _dio.get(
      '${baseurl}register/current-account',
      queryParameters: {'fiscal_year': fiscalYearBuddhist},
    );
    final data = r.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getAgencyDepositRegister({
    required int fiscalYearBuddhist,
  }) async {
    final r = await _dio.get(
      '${baseurl}register/agency-deposit',
      queryParameters: {'fiscal_year': fiscalYearBuddhist},
    );
    final data = r.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getTreasuryRemitRegister({
    required int fiscalYearBuddhist,
  }) async {
    final r = await _dio.get(
      '${baseurl}register/treasury-remit',
      queryParameters: {'fiscal_year': fiscalYearBuddhist},
    );
    final data = r.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> _genericList(String path, int? fy) async {
    final r = await _dio.get(
      '$baseurl$path',
      queryParameters: fy != null ? {'fiscal_year': fy} : null,
    );
    final data = (r.data?['data'] as List?) ?? const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── Receipt book ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listReceiptBooks(
      {String? fiscalYear}) async {
    final r = await _dio.get(
      '${baseurl}register/receipt-books',
      queryParameters: fiscalYear != null ? {'fiscal_year': fiscalYear} : null,
    );
    final data = (r.data?['data'] as List?) ?? const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createReceiptBook({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await _dio.post('${baseurl}register/receipt-books',
        data: {...body, 'token': token});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateReceiptBook(
    int id, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await _dio.patch('${baseurl}register/receipt-books/$id',
        data: {...body, 'token': token});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> deleteReceiptBook(
    int id, {
    required String token,
  }) async {
    final r = await _dio
        .delete('${baseurl}register/receipt-books/$id', data: {'token': token});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> issueReceipt(
    int bookId, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await _dio.post('${baseurl}register/receipt-books/$bookId/issues',
        data: {...body, 'token': token});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> listReceiptIssues(int bookId) async {
    final r = await _dio.get('${baseurl}register/receipt-books/$bookId/issues');
    final data = (r.data?['data'] as List?) ?? const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── Deposit guarantee ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listDeposits({
    String? depositType,
    String? status,
    String? fiscalYear,
  }) async {
    final q = <String, dynamic>{};
    if (depositType != null) q['deposit_type'] = depositType;
    if (status != null) q['status'] = status;
    if (fiscalYear != null) q['fiscal_year'] = fiscalYear;
    final r = await _dio.get('${baseurl}register/deposits',
        queryParameters: q.isEmpty ? null : q);
    final data = (r.data?['data'] as List?) ?? const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createDeposit({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await _dio
        .post('${baseurl}register/deposits', data: {...body, 'token': token});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateDeposit(
    int id, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await _dio.patch('${baseurl}register/deposits/$id',
        data: {...body, 'token': token});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> settleDeposit(
    int id, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await _dio.post('${baseurl}register/deposits/$id/settle',
        data: {...body, 'token': token});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> deleteDeposit(int id,
      {required String token}) async {
    final r = await _dio
        .delete('${baseurl}register/deposits/$id', data: {'token': token});
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// รับเงินประกัน/ภาษีหัก ณ ที่จ่าย + สร้างใบรับเงิน (ธุรกรรมเดียว)
  Future<Map<String, dynamic>> receiveDepositWithIncome({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await _dio.post(
      '${baseurl}register/deposits/receive-with-income',
      data: {...body, 'token': token},
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// คืน/นำส่ง/ริบ + สร้างใบจ่าย (ธุรกรรมเดียว)
  Future<Map<String, dynamic>> returnDepositWithExpense(
    int id, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final r = await _dio.post(
      '${baseurl}register/deposits/$id/return-with-expense',
      data: {...body, 'token': token, 'create_expense': true},
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getDepositById(int id) async {
    final r = await _dio.get('${baseurl}register/deposits/$id');
    final data = r.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getDepositReconciliation({
    String? depositType,
  }) async {
    final r = await _dio.get(
      '${baseurl}register/deposits/reconciliation',
      queryParameters:
          depositType != null ? {'deposit_type': depositType} : null,
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// ดึงทะเบียนทั้งหมดจากเซิร์ฟเวอร์ (หลายหน้า) สำหรับ mirror ลง SQLite
  Future<List<Map<String, dynamic>>> listDepositsDueSoon({
    int days = 30,
    String? fiscalYear,
  }) async {
    final q = <String, dynamic>{'days': days};
    if (fiscalYear != null) q['fiscal_year'] = fiscalYear;
    final r = await _dio.get(
      '${baseurl}register/deposits/due-soon',
      queryParameters: q,
    );
    final data = (r.data?['data'] as List?) ?? const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> pullAllDeposits() async {
    const pageSize = 100;
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= 50; page++) {
      final r = await _dio.get(
        '${baseurl}register/deposits',
        queryParameters: {'page': page},
      );
      final data = (r.data?['data'] as List?) ?? const [];
      if (data.isEmpty) break;
      for (final e in data) {
        if (e is Map) {
          out.add(Map<String, dynamic>.from(e));
        }
      }
      if (data.length < pageSize) break;
    }
    return out;
  }

  // ── Reports ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDailyBalance({String? date}) async {
    final r = await _dio.get('${baseurl}reports/daily-balance',
        queryParameters: date != null ? {'date': date} : null);
    final data = r.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getBankReconciliation({String? date}) async {
    final r = await _dio.get('${baseurl}reports/bank-reconciliation',
        queryParameters: date != null ? {'date': date} : null);
    final data = r.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getAnnualSummary({int? fiscalYear}) async {
    final r = await _dio.get('${baseurl}reports/annual-summary',
        queryParameters:
            fiscalYear != null ? {'fiscal_year': fiscalYear} : null);
    final data = r.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
