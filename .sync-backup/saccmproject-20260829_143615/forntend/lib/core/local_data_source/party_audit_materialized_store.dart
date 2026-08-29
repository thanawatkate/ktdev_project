import 'package:sqflite/sqflite.dart';

/// Persist party `/party/.../audit-log` page 1 (default filters) in SQLite.
/// [party_audit_server_line.ref_party_record_id] → [party] เมื่อมี id ตรงกันใน localdb
class PartyAuditMaterializedStore {
  PartyAuditMaterializedStore._();

  /// Stable scope key: all parties vs one party id.
  static String scopeKey(String? partyId) {
    final p = partyId?.trim() ?? '';
    return p.isEmpty ? '__all__' : p;
  }

  static Future<Set<String>> _partyIds(Transaction txn) async {
    final rows = await txn.query('party', columns: ['id']);
    return rows.map((e) => e['id']!.toString()).toSet();
  }

  static int _i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static dynamic _recordIdFromStored(String? s) {
    if (s == null || s.isEmpty) return null;
    final i = int.tryParse(s);
    return i ?? s;
  }

  /// Replace cached page-1 rows for this scope (same as API body shape).
  static Future<void> replacePageOne(
    Database db,
    String? partyId,
    Map<String, dynamic> body,
  ) async {
    final key = scopeKey(partyId);
    final meta = body['meta'];
    final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
    final data = body['data'] as List? ?? const [];

    await db.transaction((txn) async {
      await txn.delete('party_audit_scope', where: 'scope_party_id = ?', whereArgs: [key]);
      final partyIds = await _partyIds(txn);

      final scopeId = await txn.insert('party_audit_scope', {
        'scope_party_id': key,
        'total_records': _i(metaMap['total']),
        'total_pages': _i(metaMap['totalPages']),
        'per_page': _i(metaMap['perPage']) == 0 ? 200 : _i(metaMap['perPage']),
        'fetched_at': DateTime.now().toIso8601String(),
      });

      for (final raw in data) {
        final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final aid = _i(m['id']);
        if (aid == 0) continue;

        final recordStr = m['record_id']?.toString();
        String? refParty;
        if (recordStr != null &&
            recordStr.isNotEmpty &&
            partyIds.contains(recordStr)) {
          refParty = recordStr;
        }

        await txn.insert('party_audit_server_line', {
          'server_audit_id': aid,
          'ref_party_audit_scope': scopeId,
          'ref_party_record_id': refParty,
          'tablename': m['tablename']?.toString() ?? 'party',
          'record_id': recordStr,
          'action': m['action']?.toString() ?? '',
          'old_data': m['old_data']?.toString(),
          'new_data': m['new_data']?.toString(),
          'user_id': m['user_id'] == null ? null : _i(m['user_id']),
          'user_name': m['user_name']?.toString(),
          'ip_address': m['ip_address']?.toString(),
          'created': m['created']?.toString() ?? '',
        });
      }
    });
  }

  /// Body `{ data, meta }` for [_applyPartyAuditListBody] or null.
  static Future<Map<String, dynamic>?> loadPageOne(
    Database db,
    String? partyId,
  ) async {
    final key = scopeKey(partyId);
    final scopes = await db.query(
      'party_audit_scope',
      where: 'scope_party_id = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (scopes.isEmpty) return null;
    final scopeId = scopes.first['id'] as int;

    final lines = await db.query(
      'party_audit_server_line',
      where: 'ref_party_audit_scope = ?',
      whereArgs: [scopeId],
      orderBy: 'created DESC',
    );

    final data = lines.map((r) {
      return <String, dynamic>{
        'id': r['server_audit_id'],
        'tablename': r['tablename'],
        'record_id': _recordIdFromStored(r['record_id']?.toString()),
        'action': r['action'],
        'old_data': r['old_data'],
        'new_data': r['new_data'],
        'user_id': r['user_id'],
        'user_name': r['user_name'],
        'ip_address': r['ip_address'],
        'created': r['created'],
      };
    }).toList();

    return {
      'data': data,
      'meta': {
        'page': 1,
        'perPage': scopes.first['per_page'],
        'total': scopes.first['total_records'],
        'totalPages': scopes.first['total_pages'],
        'changedField': null,
      },
    };
  }
}
