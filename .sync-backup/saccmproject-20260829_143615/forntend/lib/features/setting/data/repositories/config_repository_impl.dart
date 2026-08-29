import '../../domain/entities/app_config.dart';
import '../../domain/repositories/config_repository.dart';
import '../datasources/config_local_data_source.dart';

class ConfigRepositoryImpl implements ConfigRepository {
  final ConfigLocalDataSource localDataSource;

  ConfigRepositoryImpl({required this.localDataSource});

  @override
  Future<AppConfig> loadConfig() => localDataSource.getConfig();

  @override
  Future<void> saveApiUrl(String url) => localDataSource.saveApiUrl(url);

  @override
  Future<void> resetConfig() => localDataSource.resetConfig();
}
