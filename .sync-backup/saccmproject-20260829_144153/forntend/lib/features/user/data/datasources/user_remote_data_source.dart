import 'package:dio/dio.dart';
import 'package:saccm/config.dart';

import '../../../../core/error/exceptions.dart';
import '../models/prefix_model.dart';
import '../models/user_group_model.dart';

abstract class UserRemoteDataSource {
  Future<List<PrefixModel>> getPrefixes();
  Future<List<UserGroupModel>> getUserGroups();
  Future<void> createUser({
    required String token,
    required String code,
    required String name,
    required String lastName,
    required String email,
    required String username,
    required String password,
    required String contactNumber,
    required String address,
    required String refPrefix,
    required String refUserGroup,
  });
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final Dio dio;

  UserRemoteDataSourceImpl({required this.dio});

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
  Future<List<UserGroupModel>> getUserGroups() async {
    try {
      final response = await dio.request(
        '${baseurl}usersgroup',
        options: Options(method: 'GET'),
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        return data.map((e) => UserGroupModel.fromJson(e)).toList();
      }
      throw const ServerException(message: 'Failed to load user groups');
    } on DioException catch (e) {
      throw ServerException(
          message: e.response?.data?['message'] ?? 'Network error');
    }
  }

  @override
  Future<void> createUser({
    required String token,
    required String code,
    required String name,
    required String lastName,
    required String email,
    required String username,
    required String password,
    required String contactNumber,
    required String address,
    required String refPrefix,
    required String refUserGroup,
  }) async {
    try {
      final response = await dio.request(
        '${baseurl}users',
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
          'username': username,
          'password': password,
          'contactnumber': contactNumber,
          'address': address,
          'refprefix': refPrefix,
          'refusergroup': refUserGroup,
        },
      );
      if (response.statusCode != 200) {
        throw ServerException(
            message: response.data?['message'] ?? 'Failed to save user');
      }
    } on DioException catch (e) {
      throw ServerException(
          message: e.response?.data?['message'] ?? 'Network error');
    }
  }
}
