import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-first: คำสั่งแต่งตั้ง + รายชื่อผู้ได้รับแต่งตั้ง (mirror backend schema แบบ TEXT id)
class AppointmentOrderLocalDataSource {
  final AppDatabase _appDb = AppDatabase();

  Future<Database> get _db async => _appDb.database;

  Future<List<Map<String, dynamic>>> listOrders({
    String? fiscalYear,
  }) async {
    final db = await _db;
    final where = fiscalYear != null && fiscalYear.trim().isNotEmpty
        ? 'fiscal_year = ?'
        : null;
    final args = where != null ? [fiscalYear!.trim()] : null;
    final rows = await db.query(
      'appointment_order',
      where: where,
      whereArgs: args,
      orderBy: 'docdate DESC, docno DESC',
    );
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final id = r['id']?.toString() ?? '';
      final c = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM appointment_order_member WHERE ref_appointment = ?',
        [id],
      );
      final n = (c.first['c'] as int?) ?? 0;
      out.add({
        ...r,
        'member_count': n,
      });
    }
    return out;
  }

  Future<Map<String, dynamic>?> getOrderWithMembers(String id) async {
    final db = await _db;
    final o = await db.query(
      'appointment_order',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (o.isEmpty) return null;
    final members = await db.query(
      'appointment_order_member',
      where: 'ref_appointment = ?',
      whereArgs: [id],
      orderBy: 'sort ASC, created ASC',
    );
    return {'order': o.first, 'members': members};
  }

  Future<void> deleteOrder(String id) async {
    final db = await _db;
    await db.delete(
      'appointment_order_member',
      where: 'ref_appointment = ?',
      whereArgs: [id],
    );
    await db.delete('appointment_order', where: 'id = ?', whereArgs: [id]);
  }

  /// [memberRows]: { member_name, member_position?, role_in_order, sort }
  Future<void> upsertOrder({
    String? existingId,
    required String docno,
    required String? docdateIso,
    required String orderType,
    required String subject,
    String? content,
    required String fiscalYear,
    required String status,
    required List<Map<String, dynamic>> memberRows,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final id = existingId ?? 'apo_${DateTime.now().millisecondsSinceEpoch}';
    final batchMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      var createdVal = now;
      if (existingId != null) {
        final prev = await txn.query(
          'appointment_order',
          columns: ['created'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (prev.isNotEmpty && prev.first['created'] != null) {
          createdVal = prev.first['created'].toString();
        }
        await txn.delete(
          'appointment_order_member',
          where: 'ref_appointment = ?',
          whereArgs: [id],
        );
      }

      await txn.insert(
        'appointment_order',
        {
          'id': id,
          'docno': docno.trim(),
          'docdate': docdateIso,
          'order_type': orderType,
          'subject': subject.trim(),
          'content': content?.trim(),
          'fiscal_year': fiscalYear.trim(),
          'status': status,
          'created': createdVal,
          'updated': now,
          'synced': 0,
          'last_modified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      var i = 0;
      for (final m in memberRows) {
        final name = (m['member_name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final mid = '${id}_m_${batchMs}_$i';
        i++;
        await txn.insert('appointment_order_member', {
          'id': mid,
          'ref_appointment': id,
          'member_name': name,
          'member_position': (m['member_position'] as String?)?.trim(),
          'role_in_order':
              (m['role_in_order'] as String?)?.trim().isNotEmpty == true
                  ? m['role_in_order']
                  : 'committee',
          'sort': m['sort'] ?? i,
          'created': now,
          'synced': 0,
          'last_modified': now,
        });
      }
    });
  }
}
