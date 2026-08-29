import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:saccm/core/data_sources/menu_remote_data_source.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/local_data_source/app_menu_local_data_source.dart';
import 'package:saccm/core/services/backup_full_mirror_sync.dart';
import 'package:saccm/core/services/menu_refresh_bus.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/session_token_service.dart';
import 'package:saccm/features/license/license_mode.dart';

/// ซิงก์ข้อมูลมาตรฐานจาก server กลางลง SQLite (หลัง activate / ตามคำสั่งผู้ใช้)
class MasterDataSyncService {
  MasterDataSyncService({
    Dio? dio,
    NetworkInfoService? networkInfo,
    AppDatabase? appDatabase,
    AppMenuLocalDataSource? menuLocal,
  })  : _dio = dio,
        _networkInfo = networkInfo,
        _appDatabase = appDatabase ?? AppDatabase(),
        _menuLocal = menuLocal ?? AppMenuLocalDataSource();

  final Dio? _dio;
  final NetworkInfoService? _networkInfo;
  final AppDatabase _appDatabase;
  final AppMenuLocalDataSource _menuLocal;

  Dio get _resolvedDio => _dio ?? ServiceLocator.instance.get<Dio>();

  Future<NetworkInfoService> get _net async =>
      _networkInfo ?? ServiceLocator.instance.get<NetworkInfoService>();

  /// คืน true ถ้าซิงก์สำเร็จอย่างน้อย master tables
  Future<bool> run() async {
    if (!await LicenseMode.canSyncOnline()) {
      debugPrint('MasterDataSync: not registered — skipped');
      return false;
    }

    if (!await (await _net).isConnected) {
      debugPrint('MasterDataSync: offline — skipped');
      return false;
    }

    final db = await _appDatabase.database;
    try {
      await BackupFullMirrorSync.runMastersOnly(
        dio: _resolvedDio,
        db: db,
      );
    } catch (e, st) {
      debugPrint('MasterDataSync: masters failed: $e\n$st');
      return false;
    }

    try {
      final token = await SessionTokenService.readToken();
      if (SessionTokenService.isServerJwt(token)) {
        final rows = await MenuRemoteDataSource(dio: _resolvedDio)
            .fetchAllRows(token!);
        await _menuLocal.replaceAllFromServerRows(rows);
        MenuRefreshBus.notify();
      }
    } catch (e) {
      debugPrint('MasterDataSync: menu pull skipped: $e');
    }

    return true;
  }
}
