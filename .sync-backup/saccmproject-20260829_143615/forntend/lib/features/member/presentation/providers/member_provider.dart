import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/repositories/member_repository_offline.dart' as offline;
import '../../domain/entities/member_entity.dart';
import '../../domain/repositories/member_repository.dart';
import '../../domain/usecases/create_member.dart';
import '../../domain/usecases/get_member_prefixes.dart';
import '../../../../core/usecases/usecase.dart';

class MemberProvider extends ChangeNotifier {
  List<List<String>> prefix;
  List<Map<String, dynamic>> members = [];
  String valuePrefix;
  String? code;

  bool isLoading = false;
  String? error;

  late final MemberRepository _repository;

  MemberProvider({
    required this.prefix,
    this.code,
    this.valuePrefix = "1",
    MemberRepository? repository,
  }) {
    _repository = repository ??
        ServiceLocator.instance.get<offline.MemberRepository>();
  }

  // ─── Loading methods ────────────────────────────────────────────────────────

  Future<void> loadPrefixes() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final result = await GetMemberPrefixes(_repository).call(NoParams());
    result.fold(
      (failure) => error = failure.message,
      (prefixes) {
        prefix = prefixes.map((p) => [p.id, p.prefixTh]).toList();
        if (prefixes.isNotEmpty) valuePrefix = prefixes.first.id;
        error = null;
      },
    );

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMemberList() async {
    try {
      final repo = _repository as offline.MemberRepository;
      final rows = await repo.getMemberList();
      members = rows
          .map(
            (m) => {
              'id': m.id,
              'code': m.code,
              'name': m.name,
              'email': m.email,
              'contactnumber': m.phone,
              'address': m.address,
              'synced': m.synced,
            },
          )
          .toList();
      error = null;
    } catch (e) {
      error = e.toString();
    }
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

  // ─── Save methods ────────────────────────────────────────────────────────────

  Future<bool> saveMember({
    required String token,
    required String memberCode,
    required String name,
    required String lastName,
    required String email,
    required String contactNumber,
    required String address,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final result = await CreateMember(_repository).call(CreateMemberParams(
      token: token,
      member: MemberEntity(
        code: memberCode,
        name: name,
        lastName: lastName,
        email: email,
        contactNumber: contactNumber,
        address: address,
        refPrefix: valuePrefix,
      ),
    ));

    result.fold(
      (failure) => error = failure.message,
      (_) => error = null,
    );

    isLoading = false;
    notifyListeners();
    return error == null;
  }

  Future<bool> updateMember({
    required String localId,
    required String token,
    required String memberCode,
    required String name,
    required String lastName,
    required String email,
    required String contactNumber,
    required String address,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final repo = _repository as offline.MemberRepository;
    final result = await repo.updateMember(
      localId: localId,
      token: token,
      member: MemberEntity(
        code: memberCode,
        name: name,
        lastName: lastName,
        email: email,
        contactNumber: contactNumber,
        address: address,
        refPrefix: valuePrefix,
      ),
    );

    result.fold(
      (failure) => error = failure.message,
      (_) => error = null,
    );

    isLoading = false;
    notifyListeners();
    return error == null;
  }
}
