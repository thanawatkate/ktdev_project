import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

import '../../../../core/error/exceptions.dart';
import '../models/source_group_model.dart';

abstract class IncomeTypeRemoteDataSource {
  Future<List<SourceGroupModel>> getSourceGroups();
  Future<String?> createIncomeType({
    required String token,
    required String name,
    required String remark,
    required int sourceGroupCode,
  });
}

class IncomeTypeRemoteDataSourceImpl implements IncomeTypeRemoteDataSource {
  final Dio dio;

  IncomeTypeRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<SourceGroupModel>> getSourceGroups() async {
    try {
      final response = await dio.request(
        '${baseurl}moneygroup',
        options: Options(method: 'GET'),
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data.map((e) => SourceGroupModel.fromJson(e)).toList();
      }
      throw const ServerException(message: 'Failed to load money groups');
    } on DioException catch (e) {
      final data = e.response?.data;
      throw ServerException(
          message: (data is Map ? data['message'] : null)?.toString() ?? 'Network error');
    }
  }

  @override
  Future<String?> createIncomeType({
    required String token,
    required String name,
    required String remark,
    required int sourceGroupCode,
  }) async {
    try {
      final formData = <String, dynamic>{
        'token': token,
        'name': name,
        'remark': remark,
        'refmoneygroup': sourceGroupCode,
      };
      final response = await dio.request(
        '${baseurl}incometype',
        options: Options(
          method: 'POST',
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        data: formData,
      );
      if (response.statusCode != 200) {
        throw ServerException(
            message: response.data?['message'] ?? 'Failed to save income type');
      }
      final data = response.data;
      if (data is Map) {
        final nestedId = (data['data'] is Map) ? (data['data']['id'] ?? data['data']['refid']) : null;
        final directId = data['id'] ?? data['refid'];
        return (nestedId ?? directId)?.toString();
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      throw ServerException(
          message: (data is Map ? data['message'] : null)?.toString() ?? 'Network error');
    }
  }
}
