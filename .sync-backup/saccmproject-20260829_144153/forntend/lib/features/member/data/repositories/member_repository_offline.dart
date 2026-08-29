import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:saccm/config.dart';
import 'package:saccm/core/error/failures.dart';
import 'package:saccm/core/local_data_source/member_local_data_source.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/core/utils/either.dart';
import 'package:saccm/features/member/data/datasources/member_remote_data_source.dart';
import 'package:saccm/features/member/data/models/prefix_model.dart';
import 'package:saccm/features/member/domain/entities/member_entity.dart';
import 'package:saccm/features/member/domain/entities/prefix.dart';
import 'package:saccm/features/member/domain/repositories/member_repository.dart'
    as domain;
import 'package:sqflite/sqflite.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Offline-First Member Repository
///
///   • READ  → คืน local ทันที  + background pull เมื่อ online
///   • WRITE → บันทึก local ก่อน + queue sync เสมอ
/// ─────────────────────────────────────────────────────────────────────────────
class MemberRepository implements domain.MemberRepository {
  final MemberLocalDataSource _localDataSource;
  final NetworkInfoService _networkInfo;
  final SyncService _syncService;
  final MemberRemoteDataSource _remoteDataSource;

  MemberRepository({
    required MemberLocalDataSource localDataSource,
    required NetworkInfoService networkInfo,
    required SyncService syncService,
    required MemberRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _networkInfo = networkInfo,
        _syncService = syncService,
        _remoteDataSource = remoteDataSource;

  // ─── READ: คืน local เสมอ ──────────────────────────────────────────────────

  /// คืน prefix จาก local cache ทันที
  @override
  Future<Either<Failure, List<Prefix>>> getPrefixes() async {
    try {
      final cached = await _localDataSource.db.query(
        'prefix',
        orderBy: 'prefixTh ASC',
      );
      return Right(cached
          .map((e) => PrefixModel(
                id: e['id'] as String? ?? '',
                prefixTh: e['prefixTh'] as String? ?? '',
              ))
          .toList());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  Future<List<MemberModel>> getMemberList() => _localDataSource.getAllMembers();

  Future<MemberModel?> getMemberById(String id) =>
      _localDataSource.getMemberById(id);

  // ─── WRITE: local-first + queue ────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> createMember({
    required String token,
    required MemberEntity member,
  }) async {
    try {
      final memberId =
          '${member.code}_${DateTime.now().millisecondsSinceEpoch}';

      // Step 1: Save locally immediately
      await _localDataSource.saveMember(
        MemberModel(
          id: memberId,
          code: member.code,
          name: member.name,
          email: member.email,
          phone: member.contactNumber,
          address: member.address,
        ),
        synced: false,
      );

      // Step 2: Queue for background sync
      await _syncService.addPendingRequest(
        id: 'member_create_$memberId',
        method: 'POST',
        endpoint: '${baseurl}member',
        payload: jsonEncode({
          'token': token,
          'code': member.code,
          'name': member.name,
          'lastname': member.lastName,
          'email': member.email,
          'contactnumber': member.contactNumber,
          'address': member.address,
          'refprefix': member.refPrefix,
        }),
      );

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// อัปเดตข้อมูล member ใน local แล้ว queue sync payload ล่าสุดขึ้น server
  Future<Either<Failure, void>> updateMember({
    required String localId,
    required String token,
    required MemberEntity member,
  }) async {
    try {
      await _localDataSource.saveMember(
        MemberModel(
          id: localId,
          code: member.code,
          name: member.name,
          email: member.email,
          phone: member.contactNumber,
          address: member.address,
        ),
        synced: false,
      );

      await _syncService.addPendingRequest(
        id: 'member_upsert_$localId',
        method: 'POST',
        endpoint: '${baseurl}member',
        payload: jsonEncode({
          'token': token,
          'code': member.code,
          'name': member.name,
          'lastname': member.lastName,
          'email': member.email,
          'contactnumber': member.contactNumber,
          'address': member.address,
          'refprefix': member.refPrefix,
        }),
      );

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  // ─── BACKGROUND PULL: อัปเดต local cache จาก server ──────────────────────

  /// Pull prefixes จาก server → อัปเดต local cache
  /// เรียกแบบ fire-and-forget จาก Provider
  Future<void> backgroundPullPrefixes() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    try {
      final remote = await _remoteDataSource.getPrefixes();
      final db = _localDataSource.db;
      final batch = db.batch();
      for (final p in remote) {
        batch.insert(
          'prefix',
          {
            'id': p.id,
            'prefixTh': p.prefixTh,
            'synced': 1,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      debugPrint(
          'MemberRepository: prefix pull success (${remote.length} items)');
    } catch (e) {
      debugPrint('MemberRepository: prefix pull failed: $e');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> clearLocalCache() => _localDataSource.clearAllMembers();

  Future<bool> get isConnected => _networkInfo.isConnected;

  Stream<bool> get onConnectivityChanged => _networkInfo.onConnectivityChanged;
}
