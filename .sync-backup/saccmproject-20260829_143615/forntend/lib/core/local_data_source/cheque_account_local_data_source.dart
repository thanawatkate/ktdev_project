import 'package:saccm/core/local_data_source/base_local_data_source.dart';

class ChequeAccountRow {
  const ChequeAccountRow({
    required this.id,
    required this.chequeno,
    required this.chequename,
    required this.refBank,
    required this.bankName,
    required this.sort,
    required this.use,
    required this.synced,
  });

  final String id;
  final String chequeno;
  final String chequename;
  final String refBank;
  final String bankName;
  final int sort;
  final String use;
  final bool synced;

  bool get isActive => use != 'N';

  String get displayLabel {
    final parts = <String>[
      if (chequename.isNotEmpty) chequename,
      if (bankName.isNotEmpty) '($bankName)',
      if (chequeno.isNotEmpty) '— เลขเริ่ม $chequeno',
    ];
    return parts.isEmpty ? id : parts.join(' ');
  }
}

class ChequeAccountLocalDataSource extends BaseLocalDataSource {
  Future<List<ChequeAccountRow>> listAll({bool activeOnly = false}) async {
    await ensureInitialized();
    final where = activeOnly ? "WHERE COALESCE(ca.use, 'Y') = 'Y'" : '';
    final rows = await db.rawQuery('''
      SELECT
        ca.id AS id,
        ca.chequeno AS chequeno,
        ca.chequename AS chequename,
        ca.refBank AS refBank,
        ca.sort AS sort,
        ca.use AS use,
        ca.synced AS synced,
        b.name AS bankName
      FROM cheque_account ca
      LEFT JOIN bank b ON b.id = ca.refBank
      $where
      ORDER BY ca.sort ASC, ca.chequename COLLATE NOCASE ASC
    ''');
    return rows.map(_mapRow).where((e) => e.id.isNotEmpty).toList();
  }

  ChequeAccountRow _mapRow(Map<String, Object?> r) {
    return ChequeAccountRow(
      id: r['id']?.toString() ?? '',
      chequeno: r['chequeno']?.toString() ?? '',
      chequename: r['chequename']?.toString() ?? '',
      refBank: r['refBank']?.toString() ?? '',
      bankName: r['bankName']?.toString() ?? '',
      sort: int.tryParse(r['sort']?.toString() ?? '0') ?? 0,
      use: r['use']?.toString() ?? 'Y',
      synced: (r['synced'] as int?) == 1,
    );
  }

  Future<String> insert({
    required String chequeno,
    required String chequename,
    required String refBank,
    int sort = 0,
    String use = 'Y',
    bool synced = false,
  }) async {
    await ensureInitialized();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();
    await db.insert('cheque_account', {
      'id': id,
      'chequeno': chequeno.trim(),
      'chequename': chequename.trim(),
      'refBank': refBank,
      'sort': sort,
      'use': use == 'N' ? 'N' : 'Y',
      'synced': synced ? 1 : 0,
      'lastModified': now,
    });
    return id;
  }

  Future<void> update({
    required String id,
    required String chequeno,
    required String chequename,
    required String refBank,
    int? sort,
    String? use,
    bool? synced,
  }) async {
    await ensureInitialized();
    final data = <String, Object?>{
      'chequeno': chequeno.trim(),
      'chequename': chequename.trim(),
      'refBank': refBank,
      'lastModified': DateTime.now().toIso8601String(),
    };
    if (sort != null) data['sort'] = sort;
    if (use != null) data['use'] = use == 'N' ? 'N' : 'Y';
    if (synced != null) data['synced'] = synced ? 1 : 0;
    await db.update('cheque_account', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setSynced(String id, {bool synced = true}) async {
    await ensureInitialized();
    await db.update(
      'cheque_account',
      {
        'synced': synced ? 1 : 0,
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setActive(String id, bool active) async {
    final row = await _getById(id);
    if (row == null) return;
    await update(
      id: id,
      chequeno: row.chequeno,
      chequename: row.chequename,
      refBank: row.refBank,
      use: active ? 'Y' : 'N',
    );
  }

  Future<ChequeAccountRow?> _getById(String id) async {
    final all = await listAll();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteById(String id) async {
    await ensureInitialized();
    await db.delete('cheque_account', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countPayChequeReferences(String chequeAccountId) async {
    await ensureInitialized();
    final r = await db.rawQuery(
      'SELECT COUNT(1) AS c FROM pay_cheque WHERE refChequeAccount = ?',
      [chequeAccountId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// สำหรับ dropdown รายจ่าย — [id, label]
  Future<List<List<String>>> getActiveForDropdown() async {
    final rows = await listAll(activeOnly: true);
    return rows
        .map((e) => <String>[e.id, e.displayLabel])
        .where((r) => r[0].isNotEmpty)
        .toList();
  }
}
