import 'dart:async';

import 'package:saccm/core/local_data_source/lookup_item_local_data_source.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/features/income/data/datasources/income_remote_data_source.dart';
import 'package:saccm/features/license/license_mode.dart';

/// Lookup Item Repository (Money Types, Income Types) - Offline Support
class LookupItemRepository {
  final MoneyTypeLocalDataSource _moneyTypeLocalDataSource;
  final IncomeTypeLocalDataSource _incomeTypeLocalDataSource;
  final NetworkInfoService _networkInfo;
  final IncomeRemoteDataSource _remoteDataSource;

  LookupItemRepository({
    required MoneyTypeLocalDataSource moneyTypeLocalDataSource,
    required IncomeTypeLocalDataSource incomeTypeLocalDataSource,
    required NetworkInfoService networkInfo,
    required IncomeRemoteDataSource remoteDataSource,
  })  : _moneyTypeLocalDataSource = moneyTypeLocalDataSource,
        _incomeTypeLocalDataSource = incomeTypeLocalDataSource,
        _networkInfo = networkInfo,
        _remoteDataSource = remoteDataSource;

  Future<void> _syncMoneyTypesFromRemote() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    try {
      final remoteData = await _remoteDataSource.getMoneyTypes();
      final normalized = remoteData
          .map(
            (e) => LookupItemModel(
              id: e.id,
              code: e.id,
              name: e.name,
              detail: '',
            ),
          )
          .toList();
      await _moneyTypeLocalDataSource.clearAllMoneyTypes();
      await _moneyTypeLocalDataSource.saveMoneyTypes(normalized);
    } catch (_) {}
  }

  /// รอดึง money_type + income_type จาก API (ใช้ก่อนสำรองเมื่อเทียบ digest)
  Future<void> syncLookupsFromRemoteBlocking() async {
    await _syncMoneyTypesFromRemote();
    await _syncIncomeTypesFromRemote();
  }

  Future<void> _syncIncomeTypesFromRemote() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    try {
      final remoteData = await _remoteDataSource.getIncomeTypes();
      final normalized = remoteData
          .map(
            (e) => LookupItemModel(
              id: e.id,
              code: e.id,
              name: e.name,
              detail: '',
            ),
          )
          .toList();
      await _incomeTypeLocalDataSource.clearAllIncomeTypes();
      await _incomeTypeLocalDataSource.saveIncomeTypes(normalized);
    } catch (_) {}
  }

  /// ดึง Money Types — อ่านจาก localdb เสมอ; ออนไลน์ซิงก์เบื้องหลัง
  Future<List<LookupItemModel>> getMoneyTypes() async {
    final local = await _moneyTypeLocalDataSource.getAllMoneyTypes();
    unawaited(_syncMoneyTypesFromRemote());
    return local;
  }

  /// ดึง Income Types — อ่านจาก localdb เสมอ; ออนไลน์ซิงก์เบื้องหลัง
  Future<List<LookupItemModel>> getIncomeTypes() async {
    final local = await _incomeTypeLocalDataSource.getAllIncomeTypes();
    unawaited(_syncIncomeTypesFromRemote());
    return local;
  }

  /// บันทึก money types (usually from server)
  Future<void> updateMoneyTypesCache(List<LookupItemModel> types) async {
    await _moneyTypeLocalDataSource.clearAllMoneyTypes();
    await _moneyTypeLocalDataSource.saveMoneyTypes(types);
  }

  /// บันทึก income types (usually from server)
  Future<void> updateIncomeTypesCache(List<LookupItemModel> types) async {
    await _incomeTypeLocalDataSource.clearAllIncomeTypes();
    await _incomeTypeLocalDataSource.saveIncomeTypes(types);
  }

  /// Clear all lookup caches
  Future<void> clearLocalCache() async {
    await _moneyTypeLocalDataSource.clearAllMoneyTypes();
    await _incomeTypeLocalDataSource.clearAllIncomeTypes();
  }

  /// Get connection status
  Future<bool> get isConnected => _networkInfo.isConnected;

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged => _networkInfo.onConnectivityChanged;
}
