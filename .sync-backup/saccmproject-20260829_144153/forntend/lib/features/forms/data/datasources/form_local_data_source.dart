import 'package:saccm/core/local_data_source/app_database.dart';

class FormPersonnelOption {
  final String id;
  final String fullName;

  const FormPersonnelOption({
    required this.id,
    required this.fullName,
  });
}

class FormLocalDataSource {
  final AppDatabase _db = AppDatabase();

  Future<List<FormPersonnelOption>> getActivePersonnelOptions() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT id, name, lastname
      FROM users
      WHERE COALESCE(isActive, 1) = 1
      ORDER BY name COLLATE NOCASE ASC, lastname COLLATE NOCASE ASC
    ''');
    return rows
        .map((row) {
          final id = row['id']?.toString() ?? '';
          final firstName = (row['name']?.toString() ?? '').trim();
          final lastName = (row['lastname']?.toString() ?? '').trim();
          final fullName = '$firstName $lastName'.trim();
          if (id.isEmpty || fullName.isEmpty) return null;
          return FormPersonnelOption(id: id, fullName: fullName);
        })
        .whereType<FormPersonnelOption>()
        .toList();
  }

  Future<String?> generateDocNo({
    required String tableName,
    required DateTime docDate,
  }) async {
    final db = await _db.database;
    final normalizedTable = switch (tableName.trim()) {
      'expensereq' => 'expense_req',
      'expensereqsub' => 'expense_req_sub',
      final value => value,
    };
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [normalizedTable],
    );
    if (tableExists.isEmpty) return null;

    return db.transaction((txn) async {
      final cfg = await txn.query(
        'doc_group',
        columns: ['rungroup', 'docnoformat'],
        where: 'tablename = ?',
        whereArgs: [normalizedTable],
        limit: 1,
      );
      final rungroup = cfg.isEmpty
          ? normalizedTable.toUpperCase()
          : (cfg.first['rungroup']?.toString().trim().isNotEmpty == true
              ? cfg.first['rungroup'].toString()
              : normalizedTable.toUpperCase());
      final format = cfg.isEmpty
          ? '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}'
          : (cfg.first['docnoformat']?.toString().trim().isNotEmpty == true
              ? cfg.first['docnoformat'].toString()
              : '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}');
      const marker = '__RUN__';
      final baseWithMarker = _resolveDocFormat(
        format: format,
        rungroup: rungroup,
        date: docDate,
        runText: marker,
      );
      final escaped =
          RegExp.escape(baseWithMarker).replaceAll(marker, r'(\d+)');
      final regex = RegExp('^$escaped\$');
      final likePrefix = '${baseWithMarker.split(marker).first}%';
      final rows = await txn.query(
        normalizedTable,
        columns: ['docno'],
        where: likePrefix.length > 1 ? 'docno LIKE ?' : null,
        whereArgs: likePrefix.length > 1 ? [likePrefix] : null,
      );
      var maxRun = 0;
      for (final row in rows) {
        final match = regex.firstMatch(row['docno']?.toString() ?? '');
        if (match == null) continue;
        final run = int.tryParse(match.group(1) ?? '') ?? 0;
        if (run > maxRun) maxRun = run;
      }
      return _resolveDocFormat(
        format: format,
        rungroup: rungroup,
        date: docDate,
        runText: (maxRun + 1).toString().padLeft(_runWidth(format), '0'),
      );
    });
  }

  int _runWidth(String format) {
    final m = RegExp(r'\{RUN(\d+)\}').firstMatch(format);
    if (m != null) return int.tryParse(m.group(1) ?? '') ?? 4;
    return 4;
  }

  String _resolveDocFormat({
    required String format,
    required String rungroup,
    required DateTime date,
    required String runText,
  }) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final fiscalYear =
        (date.month >= 10 ? date.year + 544 : date.year + 543).toString();
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    var out = format
        .replaceAll('{RUNGROUP}', rungroup)
        .replaceAll('{RG}', rungroup)
        .replaceAll('{FISCAL_YEAR}', fiscalYear)
        .replaceAll('{FY}', fiscalYear)
        .replaceAll('{YYYY}', yyyy)
        .replaceAll('{YY}', yy)
        .replaceAll('{MM}', mm)
        .replaceAll('{DD}', dd);
    out = out.replaceAll(RegExp(r'\{RUN\d*\}'), runText);
    if (!out.contains(runText)) {
      out = '$out-$runText';
    }
    return out;
  }
}
