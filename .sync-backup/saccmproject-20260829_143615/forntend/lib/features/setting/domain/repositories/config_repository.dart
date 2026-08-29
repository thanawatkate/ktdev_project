import '../entities/app_config.dart';

abstract class ConfigRepository {
  Future<AppConfig> loadConfig();
  Future<void> saveApiUrl(String url);
  Future<void> resetConfig();
}
