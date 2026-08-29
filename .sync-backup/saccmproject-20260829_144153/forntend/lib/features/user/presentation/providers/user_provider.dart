import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:saccm/core/local_data_source/app_database.dart';
import '../../data/datasources/user_remote_data_source.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/create_user.dart';

class UserProvider extends ChangeNotifier {
  List<List<String>> prefix;
  List<List<String>> userGroup;
  String valuePrefix;
  String? code;
  String? userGroupCode;

  bool isLoading = false;
  String? error;

  late final UserRepository _repository;

  UserProvider({
    required this.prefix,
    this.code,
    this.valuePrefix = "1",
    required this.userGroup,
    UserRepository? repository,
  }) {
    _repository = repository ??
        UserRepositoryImpl(
          remoteDataSource: UserRemoteDataSourceImpl(dio: Dio()),
        );
  }

  // ─── Loading methods ────────────────────────────────────────────────────────

  Future<void> loadPage() async {
    isLoading = true;
    error = null;
    notifyListeners();

    await Future.wait([loadPrefixes(), loadUserGroups()]);

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadPrefixes() async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'prefix',
      columns: ['id', 'prefixTh'],
      orderBy: 'id ASC',
    );
    prefix = rows
        .map((p) => [
              p['id']?.toString() ?? '',
              p['prefixTh']?.toString() ?? '',
            ])
        .where((p) => p[0].isNotEmpty)
        .toList();
    if (prefix.isNotEmpty) valuePrefix = prefix.first[0];
    error = null;
    notifyListeners();
  }

  Future<void> loadUserGroups() async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'usergroup',
      columns: ['id', 'nameth'],
      where: "use = 'Y'",
      orderBy: 'id ASC',
    );
    userGroup = rows
        .map((g) => [
              g['id']?.toString() ?? '',
              g['nameth']?.toString() ?? '',
            ])
        .where((g) => g[0].isNotEmpty)
        .toList();
    if (userGroup.isNotEmpty) userGroupCode = userGroup.first[0];
    error = null;
    notifyListeners();
  }

  // ─── State mutation helpers (kept for backward compatibility) ────────────────

  void addPrefix(List<List<String>> val) {
    prefix = val;
    notifyListeners();
  }

  void addValuePrefix(String val) {
    valuePrefix = val;
    notifyListeners();
  }

  void addCode(String val) {
    code = val;
    notifyListeners();
  }

  void addUserGroup(List<List<String>> val) {
    userGroup = val;
    notifyListeners();
  }

  void addUserGroupCode(String val) {
    userGroupCode = val;
    notifyListeners();
  }

  // ─── Save methods ────────────────────────────────────────────────────────────

  Future<bool> saveUser({
    required String token,
    required String code,
    required String name,
    required String lastName,
    required String email,
    required String username,
    required String password,
    required String contactNumber,
    required String address,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final result = await CreateUser(_repository).call(CreateUserParams(
      token: token,
      code: code,
      name: name,
      lastName: lastName,
      email: email,
      username: username,
      password: password,
      contactNumber: contactNumber,
      address: address,
      refPrefix: valuePrefix,
      refUserGroup: userGroupCode ?? '',
    ));

    result.fold(
      (failure) => error = failure.message,
      (_) => error = null,
    );

    isLoading = false;
    notifyListeners();
    return error == null;
  }
}
