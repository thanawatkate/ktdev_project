import 'base_local_data_source.dart';

/// อ่าน SQLite สำหรับหน้าจัดการประเภทรายจ่าย (`expense_type`)
class ExpenseTypeLocalDataSource extends BaseLocalDataSource {
  static const String _kExpenseTypesWithDefaultBudgetJoinSql = '''
SELECT
  et.id,
  et.code,
  et.name,
  et.remark,
  et.sort,
  et.use,
  et.refDefaultBudgetSource,
  bb.fiscal_year AS default_budget_fiscal_year,
  bsm.code AS default_master_code,
  bsm.name AS default_master_name
FROM expense_type et
LEFT JOIN budget_source_budget bb ON bb.id = et.refDefaultBudgetSource
LEFT JOIN budget_source_master bsm ON bsm.id = bb.refBudgetSourceMaster
ORDER BY et.sort ASC, et.name ASC
''';

  /// รายการประเภทรายจ่ายพร้อม join งบเริ่มต้น (แสดงใต้ชื่อบนการ์ด)
  Future<List<Map<String, Object?>>> queryExpenseTypesWithDefaultBudgetJoin() async {
    await ensureInitialized();
    return db.rawQuery(_kExpenseTypesWithDefaultBudgetJoinSql);
  }
}
