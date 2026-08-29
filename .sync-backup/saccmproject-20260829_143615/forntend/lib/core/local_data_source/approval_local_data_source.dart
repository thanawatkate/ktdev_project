import 'package:sqflite/sqflite.dart';

import 'base_local_data_source.dart';

class ApprovalLocalDataSource extends BaseLocalDataSource {
  Future<List<Map<String, dynamic>>> getLocalLog(String refId) async {
    await ensureInitialized();
    final id = refId.trim();
    if (id.isEmpty) return const [];
    final rows = await db.query(
      'expense_req',
      columns: [
        'id',
        'server_id',
        'docno',
        'approval_status',
        'reject_reason',
        'member_name',
        'created',
        'updated',
      ],
      where: 'id = ? OR server_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (rows.isEmpty) return const [];

    final row = rows.first;
    final status = row['approval_status']?.toString() ?? 'draft';
    final created = row['created']?.toString();
    final updated = row['updated']?.toString();
    final actor = row['member_name']?.toString();
    final out = <Map<String, dynamic>>[];

    if (status == 'pending' || status == 'approved' || status == 'rejected') {
      out.add({
        'action': 'submit',
        'actor_name': actor,
        'note': row['docno']?.toString(),
        'created': updated?.isNotEmpty == true ? updated : created,
      });
    }
    if (status == 'approved') {
      out.add({
        'action': 'approve',
        'actor_name': null,
        'note': null,
        'created': updated?.isNotEmpty == true ? updated : created,
      });
    }
    if (status == 'rejected') {
      out.add({
        'action': 'reject',
        'actor_name': null,
        'note': row['reject_reason']?.toString(),
        'created': updated?.isNotEmpty == true ? updated : created,
      });
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> getByStatus(String status) async {
    await ensureInitialized();
    final reqRows = await db.query(
      'expense_req',
      columns: [
        'id',
        'server_id',
        'docno',
        'amount',
        'member_name',
        'budget_source_name',
        'reject_reason',
        'updated',
        'created',
      ],
      where: 'approval_status = ?',
      whereArgs: [status],
      orderBy: 'COALESCE(updated, created) DESC',
    );
    final mappedReqRows = reqRows
        .map(
          (row) => <String, dynamic>{
            'id': row['id']?.toString() ?? '',
            'server_id': row['server_id']?.toString(),
            'status': status,
            'docno': row['docno']?.toString(),
            'amount': row['amount']?.toString(),
            'member_name': row['member_name']?.toString(),
            'budget_source_name': row['budget_source_name']?.toString(),
            'reject_reason': row['reject_reason']?.toString(),
            'updatedAt': (row['updated'] ?? row['created'] ?? '').toString(),
          },
        )
        .where((row) => (row['id']?.toString() ?? '').isNotEmpty)
        .toList();

    final cacheRows = await db.query(
      'approval_cache',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'updatedAt DESC',
    );
    final seenIds = mappedReqRows.map((row) => row['id']?.toString()).toSet();
    return [
      ...mappedReqRows,
      ...cacheRows
          .where((row) => !seenIds.contains(row['id']?.toString()))
          .map(Map<String, dynamic>.from),
    ];
  }

  Future<void> saveMany(String status, List<dynamic> items) async {
    await ensureInitialized();
    await db.delete('approval_cache', where: 'status = ?', whereArgs: [status]);
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final raw in items) {
      final item = (raw as Map).cast<String, dynamic>();
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      batch.insert(
        'approval_cache',
        {
          'id': id,
          'status': status,
          'docno': item['docno']?.toString(),
          'amount': item['amount']?.toString(),
          'member_name': item['member_name']?.toString(),
          'budget_source_name': item['budget_source_name']?.toString(),
          'reject_reason': item['reject_reason']?.toString(),
          'approver_name': item['approver_name']?.toString(),
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertOne(Map<String, dynamic> item) async {
    await ensureInitialized();
    final id = item['id']?.toString();
    final status = item['status']?.toString();
    if (id == null || id.isEmpty || status == null || status.isEmpty) return;
    await db.update(
      'expense_req',
      {
        'approval_status': status,
        'reject_reason': item['reject_reason']?.toString(),
        'updated': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ? OR server_id = ?',
      whereArgs: [id, id],
    );
    await db.insert(
      'approval_cache',
      {
        'id': id,
        'status': status,
        'docno': item['docno']?.toString(),
        'amount': item['amount']?.toString(),
        'member_name': item['member_name']?.toString(),
        'budget_source_name': item['budget_source_name']?.toString(),
        'reject_reason': item['reject_reason']?.toString(),
        'approver_name': item['approver_name']?.toString(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getLastSyncedAtIso() async {
    await ensureInitialized();
    final rows = await db.rawQuery(
      'SELECT MAX(updatedAt) AS lastSyncedAt FROM approval_cache',
    );
    if (rows.isEmpty) return null;
    final value = rows.first['lastSyncedAt']?.toString();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
