import '../entities/app_config.dart';
import '../repositories/config_repository.dart';

class GetConfig {
  final ConfigRepository repository;

  GetConfig(this.repository);

  Future<AppConfig> call() => repository.loadConfig();
}

class SaveApiUrl {
  final ConfigRepository repository;

  SaveApiUrl(this.repository);

  Future<void> call(String url) => repository.saveApiUrl(url);
}

class ResetConfig {
  final ConfigRepository repository;

  ResetConfig(this.repository);

  Future<void> call() => repository.resetConfig();
}
