import 'package:sqflite/sqflite.dart';

import 'base_local_data_source.dart';

class PrefixListItem {
  const PrefixListItem({
    required this.id,
    required this.prefixTh,
    required this.synced,
    required this.userCount,
  });

  final String id;
  final String prefixTh;
  final bool synced;
  final int userCount;
}

class PrefixLocalDataSource extends BaseLocalDataSource {
  Future<List<PrefixListItem>> getAllPrefixes() async {
    await ensureInitialized();
    final rows = await db.rawQuery('''
      SELECT
        p.id,
        p.prefixTh,
        p.synced,
        COUNT(u.id) AS user_count
      FROM prefix p
      LEFT JOIN users u ON u.refprefix = p.id
      GROUP BY p.id, p.prefixTh, p.synced
      ORDER BY p.prefixTh COLLATE NOCASE ASC
    ''');

    return rows
        .map(
          (row) => PrefixListItem(
            id: row['id']?.toString() ?? '',
            prefixTh: row['prefixTh']?.toString() ?? '',
            synced: row['synced'] == 1 || row['synced'] == true,
            userCount: int.tryParse(row['user_count']?.toString() ?? '0') ?? 0,
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<bool> existsByName(String prefixTh, {String? exceptId}) async {
    await ensureInitialized();
    final normalized = prefixTh.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final where = exceptId == null
        ? 'LOWER(TRIM(prefixTh)) = ?'
        : 'LOWER(TRIM(prefixTh)) = ? AND id <> ?';
    final args = exceptId == null ? [normalized] : [normalized, exceptId];
    final rows = await db.query(
      'prefix',
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsertPrefix({
    String? id,
    required String prefixTh,
  }) async {
    await ensureInitialized();
    final now = DateTime.now().toIso8601String();
    final normalizedName = prefixTh.trim();
    final existingId = id?.trim();
    if (existingId != null && existingId.isNotEmpty) {
      await db.update(
        'prefix',
        {
          'prefixTh': normalizedName,
          'synced': 0,
          'lastModified': now,
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return;
    }

    await db.insert(
      'prefix',
      {
        'id': 'prefix_${DateTime.now().millisecondsSinceEpoch}',
        'prefixTh': normalizedName,
        'synced': 0,
        'lastModified': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePrefix(String id) async {
    await ensureInitialized();
    await db.delete('prefix', where: 'id = ?', whereArgs: [id]);
  }
}
