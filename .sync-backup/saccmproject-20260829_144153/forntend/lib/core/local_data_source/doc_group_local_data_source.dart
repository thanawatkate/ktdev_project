import 'package:saccm/core/local_data_source/app_database.dart';

class DocGroupConfig {
  const DocGroupConfig({
    required this.id,
    required this.tableName,
    required this.name,
    required this.runGroup,
    required this.docNoFormat,
    this.runTaxGroup,
    this.taxNoFormat,
    this.use = 'Y',
  });

  final String id;
  final String tableName;
  final String name;
  final String runGroup;
  final String docNoFormat;
  final String? runTaxGroup;
  final String? taxNoFormat;
  final String use;

  factory DocGroupConfig.fromMap(Map<String, Object?> row) {
    final tableName = row['tablename']?.toString() ?? '';
    return DocGroupConfig(
      id: row['id']?.toString() ?? 'docgroup_$tableName',
      tableName: tableName,
      name: row['name']?.toString() ?? tableName,
      runGroup: row['rungroup']?.toString() ?? '',
      docNoFormat: row['docnoformat']?.toString() ?? '{RUN4}',
      runTaxGroup: row['runtaxgroup']?.toString(),
      taxNoFormat: row['taxnoformat']?.toString(),
      use: row['use']?.toString() ?? 'Y',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id.isEmpty ? 'docgroup_$tableName' : id,
      'tablename': tableName,
      'name': name,
      'rungroup': runGroup,
      'docnoformat': docNoFormat,
      'runtaxgroup': runTaxGroup,
      'taxnoformat': taxNoFormat,
      'use': use,
      'synced': 0,
      'lastModified': DateTime.now().toIso8601String(),
    };
  }

  DocGroupConfig copyWith({
    String? id,
    String? tableName,
    String? name,
    String? runGroup,
    String? docNoFormat,
    String? runTaxGroup,
    String? taxNoFormat,
    String? use,
  }) {
    return DocGroupConfig(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      name: name ?? this.name,
      runGroup: runGroup ?? this.runGroup,
      docNoFormat: docNoFormat ?? this.docNoFormat,
      runTaxGroup: runTaxGroup ?? this.runTaxGroup,
      taxNoFormat: taxNoFormat ?? this.taxNoFormat,
      use: use ?? this.use,
    );
  }
}

class DocGroupLocalDataSource {
  final AppDatabase _db = AppDatabase();

  static const receiptBookTableName = 'receipt_book';
  static const receiptBookDefaultName = 'รูปแบบเล่มใบเสร็จ';
  static const receiptBookDefaultRunGroup = 'RB';
  static const receiptBookDefaultFormat = '{RUN3}';

  Future<List<DocGroupConfig>> listDocGroups() async {
    final db = await _db.database;
    final rows = await db.query(
      'doc_group',
      orderBy: 'tablename ASC',
    );
    return rows.map(DocGroupConfig.fromMap).toList();
  }

  Future<bool> isRunGroupTaken(
    String runGroup, {
    String? excludeId,
  }) async {
    final normalized = _normalizeRunGroup(runGroup);
    if (normalized.isEmpty) return false;

    final db = await _db.database;
    final rows = await db.query(
      'doc_group',
      columns: ['id', 'rungroup'],
    );
    return rows.any((row) {
      if (row['id']?.toString() == excludeId) return false;
      return _normalizeRunGroup(row['rungroup']?.toString() ?? '') ==
          normalized;
    });
  }

  Future<DocGroupConfig> getByTableName(
    String tableName, {
    required String defaultName,
    required String defaultRunGroup,
    required String defaultFormat,
  }) async {
    final db = await _db.database;
    final normalizedTableName = tableName.trim();
    final rows = await db.query(
      'doc_group',
      where: 'tablename = ?',
      whereArgs: [normalizedTableName],
      limit: 1,
    );
    if (rows.isNotEmpty) return DocGroupConfig.fromMap(rows.first);

    return DocGroupConfig(
      id: 'docgroup_$normalizedTableName',
      tableName: normalizedTableName,
      name: defaultName,
      runGroup: defaultRunGroup,
      docNoFormat: defaultFormat,
    );
  }

  Future<DocGroupConfig> getReceiptBookConfig() {
    return getByTableName(
      receiptBookTableName,
      defaultName: receiptBookDefaultName,
      defaultRunGroup: receiptBookDefaultRunGroup,
      defaultFormat: receiptBookDefaultFormat,
    );
  }

  Future<void> upsertDocGroup(DocGroupConfig config) async {
    final db = await _db.database;
    await db.insert(
      'doc_group',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _normalizeRunGroup(String value) => value.trim().toUpperCase();
}
