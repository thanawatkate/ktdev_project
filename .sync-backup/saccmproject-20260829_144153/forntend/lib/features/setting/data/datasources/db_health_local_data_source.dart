import 'package:saccm/core/local_data_source/app_database.dart';

abstract class DbHealthLocalDataSource {
  Future<Map<String, int>> loadRelationshipHealthReport();
}

class DbHealthLocalDataSourceImpl implements DbHealthLocalDataSource {
  DbHealthLocalDataSourceImpl({AppDatabase? database})
      : _database = database ?? AppDatabase();

  final AppDatabase _database;

  @override
  Future<Map<String, int>> loadRelationshipHealthReport() {
    return _database.getRelationshipHealthReport();
  }
}
