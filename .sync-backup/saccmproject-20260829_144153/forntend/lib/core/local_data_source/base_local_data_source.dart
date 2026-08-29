import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

abstract class BaseLocalDataSource {
  Database? _db;
  Future<void>? _initFuture;

  Database get db {
    final instance = _db;
    if (instance == null) {
      throw StateError(
        'Database has not been initialized yet. '
        'Call init() or ensureInitialized() before using db.',
      );
    }
    return instance;
  }

  Future<void> init() async {
    await ensureInitialized();
  }

  Future<void> ensureInitialized() async {
    if (_db != null) return;
    _initFuture ??= _openDb();
    await _initFuture;
  }

  Future<void> _openDb() async {
    _db = await AppDatabase().database;
  }

  Future<PendingDeleteProtection> pendingDeleteProtectionFor(
    String queuePrefix,
  ) async {
    await ensureInitialized();
    final rows = await db.query(
      'pending_requests',
      columns: ['id', 'endpoint', 'payload'],
      where: 'method = ? AND id LIKE ?',
      whereArgs: ['DELETE', '$queuePrefix%'],
    );
    final ids = <String>{};
    final docnos = <String>{};
    for (final row in rows) {
      final queueId = row['id']?.toString() ?? '';
      final localId = queueId.startsWith(queuePrefix)
          ? queueId.substring(queuePrefix.length)
          : '';
      if (localId.isNotEmpty) {
        ids.add(localId);
      }

      final endpoint = row['endpoint']?.toString() ?? '';
      final endpointSegments =
          endpoint.split('/').where((e) => e.isNotEmpty).toList();
      if (endpointSegments.isNotEmpty) {
        ids.add(endpointSegments.last);
      }

      final payload = row['payload']?.toString() ?? '';
      if (payload.isEmpty) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final id =
              decoded['_localId'] ?? decoded['id'] ?? decoded['server_id'];
          final docno = decoded['docno'] ?? decoded['docNo'];
          if (id != null && id.toString().trim().isNotEmpty) {
            ids.add(id.toString().trim());
          }
          if (docno != null && docno.toString().trim().isNotEmpty) {
            docnos.add(docno.toString().trim().toLowerCase());
          }
        }
      } catch (_) {
        // Malformed payload should not block the whole pull; queued id/endpoint
        // still protect the row from being resurrected.
      }
    }
    await _addAuditDeleteProtection(queuePrefix, ids, docnos);
    return PendingDeleteProtection(ids: ids, docnos: docnos);
  }

  Future<void> _addAuditDeleteProtection(
    String queuePrefix,
    Set<String> ids,
    Set<String> docnos,
  ) async {
    const suffix = '_delete_';
    if (!queuePrefix.endsWith(suffix)) {
      return;
    }
    final module = queuePrefix.substring(0, queuePrefix.length - suffix.length);
    if (module.isEmpty) return;

    try {
      final logs = await db.query(
        'audit_log',
        columns: ['entityId', 'payload'],
        where: 'module = ? AND action = ?',
        whereArgs: [module, 'delete'],
      );
      for (final log in logs) {
        final entityId = log['entityId']?.toString().trim() ?? '';
        if (entityId.isNotEmpty) {
          ids.add(entityId);
        }

        final payload = log['payload']?.toString() ?? '';
        if (payload.isEmpty) continue;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            final id =
                decoded['_localId'] ?? decoded['id'] ?? decoded['server_id'];
            final docno = decoded['docno'] ?? decoded['docNo'];
            if (id != null && id.toString().trim().isNotEmpty) {
              ids.add(id.toString().trim());
            }
            if (docno != null && docno.toString().trim().isNotEmpty) {
              docnos.add(docno.toString().trim().toLowerCase());
            }
          }
        } catch (_) {
          // Ignore malformed historical audit payloads.
        }
      }
    } catch (_) {
      // Some tests/dev databases may not include audit_log yet.
    }
  }
}

class PendingDeleteProtection {
  const PendingDeleteProtection({
    required this.ids,
    required this.docnos,
  });

  final Set<String> ids;
  final Set<String> docnos;

  bool protects({String? id, String? docno}) {
    final normalizedId = id?.trim();
    if (normalizedId != null &&
        normalizedId.isNotEmpty &&
        ids.contains(normalizedId)) {
      return true;
    }
    final normalizedDocno = docno?.trim().toLowerCase();
    return normalizedDocno != null &&
        normalizedDocno.isNotEmpty &&
        docnos.contains(normalizedDocno);
  }
}

/// Model สำหรับเก็บ pending requests
class PendingRequest {
  final String id;
  final String method;
  final String endpoint;
  final String? payload;
  final DateTime createdAt;
  final int attempts;

  PendingRequest({
    required this.id,
    required this.method,
    required this.endpoint,
    this.payload,
    required this.createdAt,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'endpoint': endpoint,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
      };

  factory PendingRequest.fromJson(Map<String, dynamic> json) => PendingRequest(
        id: json['id'],
        method: json['method'],
        endpoint: json['endpoint'],
        payload: json['payload'],
        createdAt: DateTime.parse(json['createdAt']),
        attempts: json['attempts'] ?? 0,
      );
}

/// Service สำหรับจัดการ pending requests queue
class PendingRequestsService extends BaseLocalDataSource {
  Future<void> addPendingRequest({
    required String id,
    required String method,
    required String endpoint,
    String? payload,
  }) async {
    await ensureInitialized();
    await db.insert(
      'pending_requests',
      {
        'id': id,
        'method': method,
        'endpoint': endpoint,
        'payload': _stripSensitivePayloadFields(payload),
        'createdAt': DateTime.now().toIso8601String(),
        'attempts': 0,
      },
      // Upsert by id:
      // - duplicate save/update of same entity keeps only latest payload
      // - resets attempts so fresh data can retry from attempt 0
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String? _stripSensitivePayloadFields(String? payload) {
    if (payload == null || payload.isEmpty) return payload;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final sanitized = Map<String, dynamic>.from(decoded);
        sanitized.remove('token');
        sanitized.remove('password');
        return jsonEncode(sanitized);
      }
    } catch (_) {}
    return payload;
  }

  Future<List<PendingRequest>> getPendingRequests() async {
    await ensureInitialized();
    final results = await db.query(
      'pending_requests',
      orderBy: 'createdAt ASC',
    );

    return results
        .map((e) => PendingRequest(
              id: e['id'] as String,
              method: e['method'] as String,
              endpoint: e['endpoint'] as String,
              payload: e['payload'] as String?,
              createdAt: DateTime.parse(e['createdAt'] as String),
              attempts: e['attempts'] as int? ?? 0,
            ))
        .toList();
  }

  Future<void> removePendingRequest(String id) async {
    await ensureInitialized();
    await db.delete('pending_requests', where: 'id = ?', whereArgs: [id]);
  }

  /// ยกเลิกคิว POST/PATCH ของ party หนึ่งรายการ (ใช้ก่อนลบแถวหรือยกเลิกการแก้ไข)
  Future<void> removePendingRequestsForParty(String partyId) async {
    await ensureInitialized();
    await db.delete(
      'pending_requests',
      where: 'id = ?',
      whereArgs: ['party_create_$partyId'],
    );
    await db.delete(
      'pending_requests',
      where: 'id = ?',
      whereArgs: ['party_patch:$partyId'],
    );
    await db.delete(
      'pending_requests',
      where: 'id = ?',
      whereArgs: ['party_patch:$partyId:inactive'],
    );
  }

  Future<void> updateAttempts(String id, int attempts) async {
    await ensureInitialized();
    await db.update(
      'pending_requests',
      {'attempts': attempts},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllPending() async {
    await ensureInitialized();
    await db.delete('pending_requests');
  }
}
