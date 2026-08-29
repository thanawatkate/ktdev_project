import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

import '../../../../core/error/exceptions.dart';
import '../models/prefix_model.dart';

abstract class MemberRemoteDataSource {
  Future<List<PrefixModel>> getPrefixes();
  Future<void> createMember({
    required String token,
    required String code,
    required String name,
    required String lastName,
    required String email,
    required String contactNumber,
    required String address,
    required String refPrefix,
  });
}

class MemberRemoteDataSourceImpl implements MemberRemoteDataSource {
  final Dio dio;

  MemberRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<PrefixModel>> getPrefixes() async {
    try {
      final response = await dio.request(
        '${baseurl}prefix',
        options: Options(method: 'GET'),
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data.map((e) => PrefixModel.fromJson(e)).toList();
      }
      throw const ServerException(message: 'Failed to load prefixes');
    } on DioException catch (e) {
      throw ServerException(
          message: e.response?.data?['message'] ?? 'Network error');
    }
  }

  @override
  Future<void> createMember({
    required String token,
    required String code,
    required String name,
    required String lastName,
    required String email,
    required String contactNumber,
    required String address,
    required String refPrefix,
  }) async {
    try {
      final response = await dio.request(
        '${baseurl}member',
        options: Options(
          method: 'POST',
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        data: {
          'token': token,
          'code': code,
          'name': name,
          'lastname': lastName,
          'email': email,
          'contactnumber': contactNumber,
          'address': address,
          'refprefix': refPrefix,
        },
      );
      if (response.statusCode != 200) {
        throw ServerException(
            message: response.data?[0]?['message'] ?? 'Failed to save member');
      }
    } on DioException catch (e) {
      throw ServerException(
          message: e.response?.data?['message'] ?? 'Network error');
    }
  }
}
