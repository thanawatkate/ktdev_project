import 'package:saccm/core/local_data_source/app_database.dart';

/// Local data source สำหรับหมวดเงินนอกงบประมาณ 13 หมวด
/// (offbudget_category — seed ตอน install/upgrade)
class OffBudgetCategoryLocalDataSource {
  final AppDatabase _db = AppDatabase();

  Future<List<Map<String, Object?>>> listAll() async {
    final db = await _db.database;
    return db.query(
      'offbudget_category',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'sort ASC',
    );
  }

  Future<Map<String, Object?>?> findByCode(String code) async {
    final db = await _db.database;
    final r = await db.query('offbudget_category',
        where: 'code = ?', whereArgs: [code], limit: 1);
    return r.isEmpty ? null : r.first;
  }
}
