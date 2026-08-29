import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/income_entity.dart';
import '../models/lookup_item_model.dart';

abstract class IncomeRemoteDataSource {
  Future<List<IncomeEntity>> getIncomeList({int page = 1});
  Future<List<LookupItemModel>> getParties();

  /// ดึง `/party` ทุกหน้า — [activeOnly] ส่งเป็น query `activeOnly` ตรงกับเซิร์ฟเวอร์
  Future<List<Map<String, dynamic>>> fetchPartiesAllPages({
    bool activeOnly = true,
  });
  Future<void> createIncome({
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
    required String refMoneyType,
    required String refIncomeType,
    required String? refBudgetSource,
    required List<Map<String, dynamic>> subData,
    String? moneyDomain,
    String docStatus = 'posted',
    String? refBankAccount,
  });
  Future<List<LookupItemModel>> getMoneyTypes();
  Future<List<LookupItemModel>> getIncomeTypes();
  Future<List<LookupItemModel>> getBudgetSources();
  Future<String> getDocNo({required String tableName, required String docDate});
}

class IncomeRemoteDataSourceImpl implements IncomeRemoteDataSource {
  final Dio dio;

  IncomeRemoteDataSourceImpl({required this.dio});

  static const _partyPageSizeHint = 100;
  static const _maxPartyPages = 50;
  static const _partyPageTimeout = Duration(seconds: 25);

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ?? e.message ?? 'Network error';
    }
    if (data is String && data.trim().isNotEmpty) {
      final trimmed = data.trim().toLowerCase();
      if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
        final status = e.response?.statusCode;
        return 'Server returned an error page (HTTP $status)';
      }
      return data;
    }
    return e.message ?? 'Network error';
  }

  @override
  Future<List<LookupItemModel>> getParties() async {
    try {
      final response = await dio.request(
        '${baseurl}party',
        options: Options(method: 'GET'),
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data
            .map((e) => LookupItemModel(
                  id: e['id']?.toString() ?? '',
                  name: e['name']?.toString() ?? '',
                ))
            .toList();
      }
      throw const ServerException(message: 'Failed to load parties');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPartiesAllPages({
    bool activeOnly = true,
  }) async {
    try {
      final merged = <Map<String, dynamic>>[];
      for (var page = 1; page <= _maxPartyPages; page++) {
        final response = await dio.request(
          '${baseurl}party',
          options: Options(
            method: 'GET',
            receiveTimeout: _partyPageTimeout,
            sendTimeout: _partyPageTimeout,
          ),
          queryParameters: <String, dynamic>{
            'activeOnly': activeOnly ? 'true' : 'false',
            'page': page,
          },
        );
        if (response.statusCode != 200) {
          throw const ServerException(message: 'Failed to load parties');
        }
        final data = (response.data is Map<String, dynamic>)
            ? (response.data['data'] as List? ?? const [])
            : const [];
        if (data.isEmpty) break;
        for (final e in data) {
          merged.add(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
          );
        }
        if (data.length < _partyPageSizeHint) break;
      }
      return merged;
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<List<IncomeEntity>> getIncomeList({int page = 1}) async {
    try {
      final response = await dio.request(
        '${baseurl}income',
        options: Options(method: 'GET'),
        queryParameters: page > 1 ? <String, dynamic>{'page': page} : null,
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data
            .map((e) => IncomeEntity(
                  id: e['id']?.toString() ?? '',
                  docno: e['docno']?.toString() ?? '',
                  docdate: e['docdate']?.toString() ?? '',
                  detail: e['detail']?.toString() ?? '',
                  amount: e['amount']?.toString() ?? '',
                  remark: e['remark']?.toString() ?? '',
                  bankReference: e['bank_reference']?.toString() ??
                      e['bankReference']?.toString(),
                  created: e['created']?.toString() ?? '',
                  refBudgetSource: e['refbudgetsource']?.toString(),
                  budgetSourceName: e['budget_source_name']?.toString(),
                  refParty: e['refparty']?.toString(),
                  partyName: e['party_name']?.toString(),
                  refMoneyType: e['refmoneytype']?.toString(),
                  docStatus: e['doc_status']?.toString(),
                  moneyDomain: e['money_domain']?.toString(),
                  approvedBy: e['approved_by']?.toString(),
                  approvedAt: e['approved_at']?.toString(),
                  postedAt: e['posted_at']?.toString(),
                  changeReason: e['change_reason']?.toString(),
                ))
            .toList();
      }
      throw const ServerException(message: 'Failed to load income list');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<void> createIncome({
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
    required String refMoneyType,
    required String refIncomeType,
    required String? refBudgetSource,
    required List<Map<String, dynamic>> subData,
    String? moneyDomain,
    String docStatus = 'posted',
    String? refBankAccount,
  }) async {
    try {
      final response = await dio.request(
        '${baseurl}income',
        options: Options(
          method: 'POST',
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        data: {
          'token': token,
          'docno': docno,
          'docdate': docdate,
          'amount': amount,
          'detail': detail,
          'remark': remark,
          if (bankReference != null && bankReference.isNotEmpty)
            'bank_reference': bankReference,
          'partyname': partyName,
          if (refParty != null && refParty.isNotEmpty) 'refparty': refParty,
          'refuser': refUser,
          'refmoneytype': refMoneyType,
          'refincometype': refIncomeType,
          if (refBudgetSource != null && refBudgetSource.isNotEmpty)
            'refbudgetsource': refBudgetSource,
          if (refBankAccount != null && refBankAccount.isNotEmpty)
            'refbankaccount': refBankAccount,
          'subdata': jsonEncode(subData),
          if (moneyDomain != null && moneyDomain.isNotEmpty)
            'money_domain': moneyDomain,
          'doc_status': docStatus,
        },
      );
      if (response.statusCode != 200 ||
          response.data['status'] != 'successfully') {
        throw ServerException(
            message: response.data['message'] ?? 'Failed to save income');
      }
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<List<LookupItemModel>> getMoneyTypes() async {
    try {
      final response = await dio.request(
        '${baseurl}moneytype',
        options: Options(method: 'GET'),
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data.map((e) => LookupItemModel.fromJson(e)).toList();
      }
      throw const ServerException(message: 'Failed to load money types');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<List<LookupItemModel>> getIncomeTypes() async {
    try {
      final response = await dio.request(
        '${baseurl}incometype',
        options: Options(method: 'GET'),
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data.map((e) => LookupItemModel.fromJson(e)).toList();
      }
      throw const ServerException(message: 'Failed to load income types');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<List<LookupItemModel>> getBudgetSources() async {
    try {
      final response = await dio.request(
        '${baseurl}budgetsource',
        options: Options(method: 'GET'),
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data
            .map((e) => LookupItemModel(
                  id: e['id']?.toString() ?? '',
                  name: e['name']?.toString() ?? '',
                  refFundCategory: e['ref_income_type']?.toString() ??
                      e['refIncomeType']?.toString(),
                  refFundCategories: (e['ref_income_types'] is List)
                      ? (e['ref_income_types'] as List)
                          .map((v) => v?.toString() ?? '')
                          .where((v) => v.isNotEmpty)
                          .toList()
                      : ((e['refIncomeTypes'] is List)
                          ? (e['refIncomeTypes'] as List)
                              .map((v) => v?.toString() ?? '')
                              .where((v) => v.isNotEmpty)
                              .toList()
                          : null),
                  refBankAccount: e['refbankaccount']?.toString() ??
                      e['refBankAccount']?.toString(),
                ))
            .toList();
      }
      throw const ServerException(message: 'Failed to load budget sources');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<String> getDocNo({
    required String tableName,
    required String docDate,
  }) async {
    try {
      final response = await dio.request(
        '${baseurl}docgroup/createdocno',
        options: Options(method: 'GET'),
        queryParameters: {'tablename': tableName, 'docdate': docDate},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;
        return data?['docno']?.toString() ?? '';
      }
      throw const ServerException(message: 'Failed to get document number');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }
}
