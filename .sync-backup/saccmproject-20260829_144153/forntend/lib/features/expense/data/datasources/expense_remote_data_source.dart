import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/local_data_source/expense_local_data_source.dart';
import '../../../income/data/models/lookup_item_model.dart';

abstract class ExpenseRemoteDataSource {
  Future<List<ExpenseModel>> getExpenseList({int page = 1});
  Future<List<LookupItemModel>> getParties();
}

class ExpenseRemoteDataSourceImpl implements ExpenseRemoteDataSource {
  final Dio dio;

  ExpenseRemoteDataSourceImpl({required this.dio});

  bool _looksLikeHtml(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('<!doctype html') ||
        normalized.contains('<html');
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ?? e.message ?? 'Network error';
    }
    if (data is String && data.trim().isNotEmpty) {
      if (_looksLikeHtml(data)) {
        final status = e.response?.statusCode;
        return 'API unavailable${status != null ? ' (HTTP $status)' : ''}: server returned HTML instead of JSON';
      }
      return data;
    }
    return e.message ?? 'Network error';
  }

  @override
  Future<List<ExpenseModel>> getExpenseList({int page = 1}) async {
    try {
      final response = await dio.request(
        '${baseurl}expense',
        options: Options(method: 'GET'),
        queryParameters: page > 1 ? <String, dynamic>{'page': page} : null,
      );

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is! Map<String, dynamic>) {
          throw const ServerException(
            message: 'Invalid response format: expected JSON object',
          );
        }
        final data = body['data'] as List? ?? [];
        return data
            .map(
              (e) => ExpenseModel(
                id: e['id']?.toString() ?? '',
                docno: e['docno']?.toString() ?? '',
                docdate: e['docdate']?.toString() ?? '',
                detail: e['detail']?.toString() ?? '',
                amount: e['amount']?.toString() ?? '',
                remark: e['remark']?.toString() ?? '',
                refExpenseReq: e['refexpensereq']?.toString(),
                refParty: e['refparty']?.toString(),
                partyName: e['party_name']?.toString(),
                created: e['created']?.toString() ?? '',
              ),
            )
            .toList();
      }

      throw const ServerException(message: 'Failed to load expense list');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<List<LookupItemModel>> getParties() async {
    try {
      final response = await dio.request(
        '${baseurl}party',
        options: Options(method: 'GET'),
      );

      if (response.statusCode == 200) {
        final body = response.data;
        if (body is! Map<String, dynamic>) {
          throw const ServerException(
            message: 'Invalid response format: expected JSON object',
          );
        }
        final data = body['data'] as List? ?? [];
        return data
            .map(
              (e) => LookupItemModel(
                id: e['id']?.toString() ?? '',
                name: e['name']?.toString() ?? '',
              ),
            )
            .toList();
      }

      throw const ServerException(message: 'Failed to load party list');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }
}
