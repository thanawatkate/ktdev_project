import 'dart:convert';

import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:sqflite/sqflite.dart';

class AuditLogEntry {
  final String id;
  final String module;
  final String action;
  final String entityId;
  final Map<String, dynamic>? payload;
  final String createdAt;

  const AuditLogEntry({
    required this.id,
    required this.module,
    required this.action,
    required this.entityId,
    required this.payload,
    required this.createdAt,
  });
}

class AuditLogLocalDataSource extends BaseLocalDataSource {
  Future<void> logEvent({
    required String module,
    required String action,
    required String entityId,
    Map<String, dynamic>? payload,
  }) async {
    final now = DateTime.now();
    await db.insert(
      'audit_log',
      {
        'id': '${module}_${action}_${entityId}_${now.microsecondsSinceEpoch}',
        'module': module,
        'action': action,
        'entityId': entityId,
        'payload': payload == null ? null : jsonEncode(payload),
        'createdAt': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AuditLogEntry>> getRecentLogs({
    int limit = 200,
    int offset = 0,
  }) async {
    final rows = await db.query(
      'audit_log',
      orderBy: 'createdAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((row) {
      final payloadRaw = row['payload'] as String?;
      return AuditLogEntry(
        id: row['id'] as String,
        module: row['module'] as String,
        action: row['action'] as String,
        entityId: row['entityId'] as String,
        payload: payloadRaw == null
            ? null
            : (jsonDecode(payloadRaw) as Map<String, dynamic>),
        createdAt: (row['createdAt'] as String?) ?? '',
      );
    }).toList();
  }

  Future<int> countLogs() async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM audit_log');
    if (rows.isEmpty) return 0;
    return (rows.first['total'] as int?) ?? 0;
  }
}
