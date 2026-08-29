import 'package:sqflite/sqflite.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';

class LookupItemModel {
  final String id;
  final String code;
  final String name;
  final String detail;

  LookupItemModel({
    required this.id,
    required this.code,
    required this.name,
    required this.detail,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'detail': detail,
  };

  factory LookupItemModel.fromJson(Map<String, dynamic> json) => LookupItemModel(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    detail: json['detail'] as String? ?? '',
  );
}

class MoneyTypeLocalDataSource extends BaseLocalDataSource {
  /// บันทึก money types
  Future<void> saveMoneyTypes(List<LookupItemModel> types) async {
    final batch = db.batch();
    for (final type in types) {
      batch.insert(
        'money_type',
        {
          'id': type.id,
          'code': type.code,
          'name': type.name,
          'detail': type.detail,
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// ดึง money types ทั้งหมด
  Future<List<LookupItemModel>> getAllMoneyTypes() async {
    final results = await db.query('money_type', orderBy: 'name ASC');
    return results
        .map((e) => LookupItemModel(
          id: e['id'] as String? ?? '',
          code: e['code'] as String? ?? '',
          name: e['name'] as String? ?? '',
          detail: e['detail'] as String? ?? '',
        ))
        .toList();
  }

  /// ล้าง money types
  Future<void> clearAllMoneyTypes() async {
    await db.delete('money_type');
  }
}

class IncomeTypeLocalDataSource extends BaseLocalDataSource {
  /// บันทึก income types
  Future<void> saveIncomeTypes(List<LookupItemModel> types) async {
    await ensureInitialized();
    final batch = db.batch();
    for (final type in types) {
      batch.insert(
        'income_type',
        {
          'id': type.id,
          'code': type.code,
          'name': type.name,
          'detail': type.detail,
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// ดึง income types ทั้งหมด
  Future<List<LookupItemModel>> getAllIncomeTypes() async {
    await ensureInitialized();
    final results = await db.query('income_type', orderBy: 'name ASC');
    return results
        .map((e) => LookupItemModel(
          id: e['id'] as String? ?? '',
          code: e['code'] as String? ?? '',
          name: e['name'] as String? ?? '',
          detail: e['detail'] as String? ?? '',
        ))
        .toList();
  }

  /// ล้าง income types
  Future<void> clearAllIncomeTypes() async {
    await ensureInitialized();
    await db.delete('income_type');
  }

  Future<List<Map<String, Object?>>> queryIncomeTypeList({
    required String searchQuery,
    required String sortBy,
  }) async {
    await ensureInitialized();
    final q = searchQuery.trim().toLowerCase();
    final whereClause = q.isEmpty
        ? ''
        : '''
        WHERE LOWER(COALESCE(i.name, '')) LIKE ?
           OR LOWER(COALESCE(i.code, '')) LIKE ?
           OR LOWER(COALESCE(i.detail, '')) LIKE ?
      ''';
    final whereArgs =
        q.isEmpty ? const <Object?>[] : <Object?>['%$q%', '%$q%', '%$q%'];

    return db.rawQuery('''
        SELECT
          i.id,
          COALESCE(i.code, '') AS code,
          COALESCE(i.name, '') AS name,
          COALESCE(i.detail, '') AS detail,
          COALESCE(i.lastModified, '') AS lastModified,
          COALESCE(linked.linkedCount, 0) AS linkedCount
        FROM income_type i
        LEFT JOIN (
          SELECT refFundCategory, COUNT(id) AS linkedCount
          FROM budget_source_master
          WHERE refFundCategory IS NOT NULL
          GROUP BY refFundCategory
        ) AS linked ON linked.refFundCategory = i.id
        $whereClause
        ORDER BY ${_orderByClause(sortBy)}
      ''', whereArgs);
  }

  Future<List<Map<String, Object?>>> queryMoneyGroupOptions() async {
    await ensureInitialized();
    return db.query(
      'money_group',
      columns: ['id', 'name'],
      orderBy: 'sort ASC, name ASC',
    );
  }

  Future<List<Map<String, Object?>>> queryBudgetSourceOptions() async {
    await ensureInitialized();
    return db.query(
      'budget_source_master',
      columns: ['id', 'name'],
      orderBy: 'name ASC',
    );
  }

  Future<Set<String>> queryLinkedBudgetSourceIds(String incomeTypeId) async {
    await ensureInitialized();
    final normalizedId = incomeTypeId.trim();
    if (normalizedId.isEmpty) return <String>{};

    final rows = await db.query(
      'budget_source_master',
      columns: ['id'],
      where: 'refFundCategory = ?',
      whereArgs: [normalizedId],
    );
    return rows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, Object?>>> queryBudgetSourcesByIds(
    Set<String> masterIds,
  ) async {
    await ensureInitialized();
    final args = masterIds.where((id) => id.trim().isNotEmpty).toList();
    if (args.isEmpty) return const <Map<String, Object?>>[];

    final placeholders = List.filled(args.length, '?').join(',');
    return db.query(
      'budget_source_master',
      columns: ['id', 'refmoneygroup', 'budget_type', 'refFundCategory'],
      where: 'id IN ($placeholders)',
      whereArgs: args,
    );
  }

  Future<Map<String, int>> countIncomeTypeReferences(String incomeTypeId) async {
    await ensureInitialized();

    Future<int> countRefs(String sql) async {
      final rows = await db.rawQuery(sql, [incomeTypeId]);
      if (rows.isEmpty) return 0;
      final value = rows.first['c'];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '0') ?? 0;
    }

    return <String, int>{
      'รายการรับเงิน': await countRefs(
        'SELECT COUNT(1) AS c FROM income_sub WHERE refIncomeType = ?',
      ),
      'รายการจ่ายเงิน': await countRefs(
        'SELECT COUNT(1) AS c FROM expense_sub WHERE refFundCategory = ?',
      ),
      'รายการขอเบิก': await countRefs(
        'SELECT COUNT(1) AS c FROM expense_req_sub WHERE refFundCategory = ?',
      ),
      'สัญญายืม': await countRefs(
        'SELECT COUNT(1) AS c FROM loan_sub WHERE refFundCategory = ?',
      ),
      'ชำระคืนเงินยืม': await countRefs(
        'SELECT COUNT(1) AS c FROM repay_loan_sub WHERE refFundCategory = ?',
      ),
    };
  }

  String _orderByClause(String sortBy) {
    switch (sortBy) {
      case 'linked_desc':
        return 'linkedCount DESC, name COLLATE NOCASE ASC';
      case 'updated_desc':
        return 'lastModified DESC, name COLLATE NOCASE ASC';
      case 'name_asc':
      default:
        return 'name COLLATE NOCASE ASC';
    }
  }
}
