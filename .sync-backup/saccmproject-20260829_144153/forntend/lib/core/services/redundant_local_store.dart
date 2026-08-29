import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saccm/core/security/guard_secret.dart';
import 'package:saccm/core/services/secure_credential_store.dart';

/// เก็บค่าซ้ำหลายที่ (secure storage + ไฟล์ใน app-support dir)
/// เพื่อกัน reset ด้วยการลบ app data อย่างเดียว — ต้องลบครบทุก anchor
///
/// อ่านกลับมาได้ "ทุกค่า" ที่เจอ ให้ผู้เรียกตัดสินใจเอง
/// (เช่น trial ใช้ค่าวันเริ่มที่ "เก่าที่สุด")
///
/// กันแกะ/แก้ค่า: ทุกค่าถูกห่อด้วย HMAC (tamper-evident) ตาม
/// `namespace + key + value` ถ้าลายเซ็นไม่ตรง = ถูกแก้มือ → ทิ้งค่านั้น
/// (ยังรองรับค่าเก่าที่ยังไม่เซ็น แล้ว re-sign ให้อัตโนมัติ)
class RedundantLocalStore {
  RedundantLocalStore(this.namespace);

  final String namespace;

  String _secureKey(String key) => '${namespace}__$key';

  /// ลายเซ็นของค่าหนึ่ง ๆ — ผูกกับ namespace+key เพื่อกันสลับค่า/คีย์ข้ามกัน
  String _sign(String key, String value) =>
      GuardSecret.signStoreValue('$namespace|$key|$value');

  /// ห่อค่าเป็น payload ที่เซ็นแล้ว (JSON)
  String _wrap(String key, String value) => jsonEncode({
        'v': value,
        's': _sign(key, value),
      });

  /// แกะค่าจาก payload; คืน null ถ้าลายเซ็นไม่ตรง (ถูกแก้มือ)
  /// รองรับค่าเก่าแบบ plain string (ไม่มีลายเซ็น) เพื่อ migrate
  String? _unwrap(String key, String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['v'] is String && decoded['s'] is String) {
        final value = decoded['v'] as String;
        final sig = decoded['s'] as String;
        return _constantTimeEquals(sig, _sign(key, value)) ? value : null;
      }
    } catch (_) {
      // ไม่ใช่ JSON → ถือเป็นค่า legacy แบบ plain
    }
    // legacy plain value (ก่อนมีลายเซ็น) — ยอมรับเพื่อ migrate
    return raw;
  }

  /// เทียบสตริงแบบเวลาคงที่ กัน timing attack เบื้องต้น
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<File?> _file() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}.$namespace.json');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _readFileMap() async {
    final file = await _file();
    if (file == null || !await file.exists()) return {};
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> write(String key, String value) async {
    final wrapped = _wrap(key, value);
    await SecureCredentialStore.write(_secureKey(key), wrapped);
    final file = await _file();
    if (file == null) return;
    try {
      final map = await _readFileMap();
      map[key] = wrapped;
      await file.writeAsString(jsonEncode(map), flush: true);
    } catch (_) {
      // ไฟล์ anchor เขียนไม่ได้ก็ยังเหลือ secure storage
    }
  }

  /// ค่าทั้งหมดที่หาเจอจากทุกแหล่ง (อาจซ้ำ) — ไม่รวม null/ว่าง
  /// ค่าที่ลายเซ็นไม่ตรง (ถูกแก้มือ) จะถูกตัดทิ้งโดยอัตโนมัติ
  Future<List<String>> readAll(String key) async {
    final out = <String>[];
    final secureValue =
        _unwrap(key, await SecureCredentialStore.read(_secureKey(key)));
    if (secureValue != null && secureValue.isNotEmpty) out.add(secureValue);
    final fileRaw = (await _readFileMap())[key];
    final fileValue = fileRaw is String ? _unwrap(key, fileRaw) : null;
    if (fileValue != null && fileValue.isNotEmpty) out.add(fileValue);
    return out;
  }

  Future<String?> readFirst(String key) async {
    final all = await readAll(key);
    return all.isEmpty ? null : all.first;
  }

  /// เขียนค่าเดิมกลับไปทุก anchor ที่ยังหายไป (self-heal)
  Future<void> reinforce(String key, String value) async {
    await write(key, value);
  }
}
