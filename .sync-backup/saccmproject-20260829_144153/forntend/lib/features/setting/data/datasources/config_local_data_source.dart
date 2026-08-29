import 'package:saccm/config.dart';

import '../../domain/entities/app_config.dart';

abstract class ConfigLocalDataSource {
  Future<AppConfig> getConfig();
  Future<void> saveApiUrl(String url);
  Future<void> resetConfig();
}

class ConfigLocalDataSourceImpl implements ConfigLocalDataSource {
  ConfigLocalDataSourceImpl();

  @override
  Future<AppConfig> getConfig() async {
    await RuntimeConfig.loadFromPreferences();
    final apiUrl = RuntimeConfig.apiBaseUrl;

    return AppConfig(
      apiUrl: apiUrl,
    );
  }

  @override
  Future<void> saveApiUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isNotEmpty) {
      await RuntimeConfig.setApiBaseUrl(trimmed);
    }
  }

  @override
  Future<void> resetConfig() async {
    await RuntimeConfig.resetApiBaseUrl();
  }
}
