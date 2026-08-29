import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/data_sources/sync_digest_remote_data_source.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/local_data_source/app_database_startup.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:saccm/core/platform/local_file_ops.dart';
import 'package:saccm/core/services/backup_full_mirror_sync.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';

/// ผลตรวจก่อนสำรองเมื่อเชื่อมต่อเซิร์ฟเวอร์ได้
class BackupPrecheckOnline {
  BackupPrecheckOnline({
    required this.serverDigest,
    required this.localDigest,
    required this.mismatchedTables,
  });

  final Map<String, int> serverDigest;
  final Map<String, int> localDigest;
  final List<String> mismatchedTables;

  bool get isAligned => mismatchedTables.isEmpty;
}

/// บริการสำรอง/กู้คืนไฟล์ SQLite — ออนไลน์จะซิงก์คิว + ดึงข้อมูลหลักแบบหลายหน้าแล้วเทียบ digest กับเซิร์ฟเวอร์
class BackupRestoreService {
  BackupRestoreService({
    required NetworkInfoService networkInfo,
    required SyncService syncService,
    required PendingRequestsService pendingService,
    required SharedPreferences prefs,
    required Dio dio,
  })  : _networkInfo = networkInfo,
        _syncService = syncService,
        _pendingService = pendingService,
        _prefs = prefs,
        _dio = dio,
        _digestRemote = SyncDigestRemoteDataSource(dio: dio);

  final NetworkInfoService _networkInfo;
  final SyncService _syncService;
  final PendingRequestsService _pendingService;
  final SharedPreferences _prefs;
  final Dio _dio;
  final SyncDigestRemoteDataSource _digestRemote;

  static const _maxSyncRounds = 12;
  static const _prefsTokenKey = 'token';

  bool _isServerSessionToken(String? t) {
    final s = (t ?? '').trim();
    return s.isNotEmpty && !s.startsWith('local_');
  }

  Future<bool> validateSaccmSqliteFile(String path) async {
    Database? db;
    try {
      db = await openDatabase(
        path,
        readOnly: true,
        singleInstance: false,
      );
      final tables = await db.rawQuery(
        "SELECT 1 AS ok FROM sqlite_master WHERE type='table' AND name='income' LIMIT 1",
      );
      return tables.isNotEmpty;
    } catch (_) {
      return false;
    } finally {
      if (db != null) {
        await db.close();
      }
    }
  }

  /// รันคิวซิงก์จนนิ่ง แล้ว mirror ตารางหลักจาก REST ลง SQLite ให้ตรงกับเซิร์ฟเวอร์ก่อนเทียบ digest
  Future<void> reconcileForServerDigest() async {
    for (var i = 0; i < _maxSyncRounds; i++) {
      await _syncService.syncPendingRequests();
      final left = await _pendingService.getPendingRequests();
      if (left.isEmpty) break;
    }
    final pendingAfter = await _pendingService.getPendingRequests();
    if (pendingAfter.isNotEmpty) {
      throw StateError(
        TransactionUiText.backupPendingQueueNotEmpty(pendingAfter.length),
      );
    }
    final db = await AppDatabase().database;
    await BackupFullMirrorSync.run(dio: _dio, db: db);
  }

  List<String> _diffDigests(
    Map<String, int> server,
    Map<String, int> local,
  ) {
    final keys = {...server.keys, ...local.keys};
    final bad = <String>[];
    for (final k in keys) {
      final a = server[k] ?? -999;
      final b = local[k] ?? -998;
      if (a < 0 || b < 0) continue;
      if (a != b) bad.add(k);
    }
    bad.sort();
    return bad;
  }

  /// เมื่อออนไลน์และมี JWT — ซิงก์แล้วเทียบ digest; เมื่อออฟไลน์หรือโทเคน local คืน null (สำรองจากเครื่องอย่างเดียว)
  Future<BackupPrecheckOnline?> runOnlinePrecheckOrNull() async {
    if (kIsWeb) return null;
    if (!await _networkInfo.isConnected) return null;
    final token = _prefs.getString(_prefsTokenKey);
    if (!_isServerSessionToken(token)) return null;

    await reconcileForServerDigest();

    Map<String, int> server;
    try {
      server = await _digestRemote.fetchDigest(token: token!);
    } on DioException catch (e) {
      throw Exception(e.message ?? 'เชื่อมต่อ digest ไม่สำเร็จ');
    }

    final local = await AppDatabase().getSyncDigestCounts();
    final bad = _diffDigests(server, local);
    return BackupPrecheckOnline(
      serverDigest: server,
      localDigest: local,
      mismatchedTables: bad,
    );
  }

  /// สำรองไปไฟล์ — ถ้า [requireOnlineAlignment] เป็น true จะ throw หาก digest ไม่ตรง
  Future<String> exportDatabaseFile({
    bool requireOnlineAlignment = true,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('ยังไม่รองรับการสำรองบนเว็บ');
    }
    BackupPrecheckOnline? precheck;
    if (requireOnlineAlignment && await _networkInfo.isConnected) {
      final token = _prefs.getString(_prefsTokenKey);
      if (_isServerSessionToken(token)) {
        precheck = await runOnlinePrecheckOrNull();
        if (precheck != null && !precheck.isAligned) {
          throw StateError(
            'ข้อมูลในเครื่องไม่ตรงกับเซิร์ฟเวอร์ที่ตาราง: '
            '${precheck.mismatchedTables.join(', ')}',
          );
        }
      }
    }

    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final outPath = await buildBackupExportPath('saccm_backup_$stamp.db');
    await AppDatabase().vacuumIntoPath(outPath);
    return outPath;
  }

  /// เตรียมกู้คืน: เก็บ path ไฟล์ที่เลือก — เปิดแอปรอบถัดไปจะแทนที่ฐานข้อมูล (ดู [applyPendingSaccmDbRestoreIfAny])
  Future<void> scheduleRestoreFromPickedFile(String absolutePath) async {
    if (kIsWeb) {
      throw UnsupportedError('ยังไม่รองรับการกู้คืนบนเว็บ');
    }
    final staged = await stageLocalFileForRestore(
      sourcePath: absolutePath,
      stagedFilename:
          'saccm_restore_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    await _prefs.setString(kPendingSaccmDbRestorePathKey, staged);
  }
}
