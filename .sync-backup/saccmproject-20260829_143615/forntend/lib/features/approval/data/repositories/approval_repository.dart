import 'dart:convert';

import 'package:saccm/config.dart';
import 'package:saccm/core/local_data_source/approval_local_data_source.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/features/approval/data/datasources/approval_remote_data_source.dart';
import 'package:saccm/features/license/license_mode.dart';

/// สถานะรายการอนุมัติหลังอ่านจากเครื่องหรือดึงจากเซิร์ฟเวอร์
class ApprovalListsSnapshot {
  const ApprovalListsSnapshot({
    required this.pending,
    required this.approved,
    required this.rejected,
    this.lastSyncedAtIso,
  });

  final List<dynamic> pending;
  final List<dynamic> approved;
  final List<dynamic> rejected;
  final String? lastSyncedAtIso;
}

/// Local-first: อ่าน/บันทึก SQLite ผ่าน [ApprovalLocalDataSource] — ดึง API ผ่าน [ApprovalRemoteDataSource]
class ApprovalRepository {
  ApprovalRepository({
    required ApprovalRemoteDataSource remoteDataSource,
    required ApprovalLocalDataSource localDataSource,
    SyncService? syncService,
  })  : _remote = remoteDataSource,
        _local = localDataSource,
        _syncService = syncService;

  final ApprovalRemoteDataSource _remote;
  final ApprovalLocalDataSource _local;
  final SyncService? _syncService;

  Future<ApprovalListsSnapshot> loadLocalSnapshot() async {
    final pending = await _local.getByStatus('pending');
    final approved = await _local.getByStatus('approved');
    final rejected = await _local.getByStatus('rejected');
    final last = await _local.getLastSyncedAtIso();
    return ApprovalListsSnapshot(
      pending: List<dynamic>.from(pending),
      approved: List<dynamic>.from(approved),
      rejected: List<dynamic>.from(rejected),
      lastSyncedAtIso: last,
    );
  }

  /// ดึงทั้งสามสถานะจากเซิร์ฟเวอร์แล้วเขียนลง `approval_cache`
  Future<void> syncAllFromRemote() async {
    if (!await LicenseMode.canSyncOnline()) return;
    final results = await Future.wait([
      _remote.fetchByStatus('pending'),
      _remote.fetchByStatus('approved'),
      _remote.fetchByStatus('rejected'),
    ]);
    await _local.saveMany('pending', results[0]);
    await _local.saveMany('approved', results[1]);
    await _local.saveMany('rejected', results[2]);
  }

  Future<void> upsertLocalItem(Map<String, dynamic> item) =>
      _local.upsertOne(item);

  Future<void> submitApprove({
    required String id,
    required String? token,
    required String note,
  }) async {
    await _queueDecision(
      id: id,
      action: 'approve',
      token: token,
      payload: {'note': note},
    );
  }

  Future<void> submitReject({
    required String id,
    required String? token,
    required String rejectReason,
  }) async {
    await _queueDecision(
      id: id,
      action: 'reject',
      token: token,
      payload: {'reject_reason': rejectReason},
    );
  }

  Future<void> _queueDecision({
    required String id,
    required String action,
    required String? token,
    required Map<String, dynamic> payload,
  }) async {
    final syncService = _syncService;
    if (syncService == null || id.trim().isEmpty) {
      throw StateError('ไม่สามารถเข้าคิวซิงค์รายการอนุมัติได้');
    }
    await syncService.addPendingRequest(
      id: 'approval_${action}_${id}_${DateTime.now().millisecondsSinceEpoch}',
      method: 'POST',
      endpoint: '${baseurl}approval/$id/$action',
      payload: jsonEncode({
        'token': token,
        ...payload,
      }),
    );
  }

  Future<List<dynamic>> fetchApprovalLog(String refId) async {
    final localRows = await _local.getLocalLog(refId);
    if (localRows.isNotEmpty) return List<dynamic>.from(localRows);
    if (!await LicenseMode.canSyncOnline()) return const [];
    return _remote
        .fetchLog(refTable: 'expensereq', refId: refId)
        .timeout(const Duration(seconds: 4));
  }
}
