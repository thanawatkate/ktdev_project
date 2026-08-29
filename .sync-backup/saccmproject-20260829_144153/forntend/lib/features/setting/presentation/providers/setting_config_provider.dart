import 'package:flutter/material.dart';
import 'package:saccm/features/setting/data/datasources/config_local_data_source.dart';
import 'package:saccm/features/setting/data/repositories/config_repository_impl.dart';
import 'package:saccm/features/setting/domain/entities/app_config.dart';
import 'package:saccm/features/setting/domain/usecases/config_usecases.dart';

/// ผู้จัดการการตั้งค่าระบบ
class SettingProvider extends ChangeNotifier {
  late final ConfigRepositoryImpl _repository;
  late final GetConfig _getConfig;
  late final SaveApiUrl _saveApiUrl;
  late final ResetConfig _resetConfig;

  AppConfig? _config;
  bool _isLoaded = false;
  String? _error;

  bool _disposed = false;

  // Getters
  AppConfig? get config => _config;
  bool get isLoaded => _isLoaded;
  String? get error => _error;

  String get apiUrl => _config?.apiUrl ?? 'http://localhost:3801';

  SettingProvider() {
    final dataSource = ConfigLocalDataSourceImpl();
    _repository = ConfigRepositoryImpl(localDataSource: dataSource);
    _getConfig = GetConfig(_repository);
    _saveApiUrl = SaveApiUrl(_repository);
    _resetConfig = ResetConfig(_repository);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// โหลดการตั้งค่า
  Future<void> loadConfig() async {
    if (_isLoaded) return;

    try {
      _error = null;
      _config = await _getConfig.call();
      _isLoaded = true;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (!_disposed) notifyListeners();
    }
  }

  /// บันทึก API URL
  Future<void> setApiUrl(String url) async {
    try {
      _error = null;
      await _saveApiUrl.call(url);
      _config = _config?.copyWith(apiUrl: url.trim());
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (!_disposed) notifyListeners();
    }
  }

  /// รีเซ็ตการตั้งค่า
  Future<void> resetConfig() async {
    try {
      _error = null;
      await _resetConfig.call();
      _config = AppConfig(
        apiUrl: 'http://localhost:3801',
      );
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (!_disposed) notifyListeners();
    }
  }
}
