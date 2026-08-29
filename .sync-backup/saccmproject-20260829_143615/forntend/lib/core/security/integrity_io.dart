import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'guard_secret.dart';
import 'integrity_result.dart';

/// ชื่อไฟล์ manifest ที่วางคู่กับ .exe ตอน build (สร้างโดย build script)
const String _manifestFileName = 'integrity_manifest.json';

/// ตรวจความถูกต้องของไฟล์ binary หลัก (.exe + dll สำคัญ) เทียบกับ manifest
/// ที่เซ็นด้วย HMAC ตอน build
///
/// รูปแบบ manifest:
/// ```json
/// {
///   "version": 1,
///   "files": { "saccm.exe": "<sha256hex>", "flutter_windows.dll": "..." },
///   "signature": "<hmac-sha256 ของ canonical(files)>"
/// }
/// ```
///
/// พฤติกรรม:
///  - debug/profile build → ข้าม (คืน skipped) เพื่อไม่ขวางตอนพัฒนา
///  - ไม่พบ manifest → ข้าม (build ที่ยังไม่ได้ทำ protected packaging)
///  - signature ไม่ตรง / ไฟล์ถูกแก้ / ไฟล์หาย → failed
Future<IntegrityResult> verifyBinaryIntegrity() async {
  // ตรวจเฉพาะ release build เท่านั้น
  if (kDebugMode || kProfileMode) {
    return const IntegrityResult.skipped('non-release-build');
  }
  if (!(Platform.isWindows)) {
    return const IntegrityResult.skipped('platform-unsupported');
  }

  try {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final manifestFile =
        File('${exeDir.path}${Platform.pathSeparator}$_manifestFileName');
    if (!await manifestFile.exists()) {
      return const IntegrityResult.skipped('no-manifest');
    }

    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) {
      return const IntegrityResult.failed(
        offendingFiles: [_manifestFileName],
        reason: 'manifest-malformed',
      );
    }

    final files = decoded['files'];
    final signature = decoded['signature'];
    if (files is! Map || signature is! String) {
      return const IntegrityResult.failed(
        offendingFiles: [_manifestFileName],
        reason: 'manifest-incomplete',
      );
    }

    // ตรวจลายเซ็น manifest ก่อน — กันแก้รายการ hash
    final expectedSig = GuardSecret.signIntegrity(_canonicalFiles(files));
    if (!_constantTimeEquals(signature, expectedSig)) {
      return const IntegrityResult.failed(
        offendingFiles: [_manifestFileName],
        reason: 'manifest-signature-mismatch',
      );
    }

    // เทียบ hash ไฟล์จริงทีละไฟล์
    final offending = <String>[];
    for (final entry in files.entries) {
      final name = entry.key.toString();
      final expectedHash = entry.value.toString().toLowerCase();
      final target = File('${exeDir.path}${Platform.pathSeparator}$name');
      if (!await target.exists()) {
        offending.add(name);
        continue;
      }
      final actualHash = await _sha256OfFile(target);
      if (actualHash != expectedHash) offending.add(name);
    }

    if (offending.isNotEmpty) {
      return IntegrityResult.failed(
        offendingFiles: offending,
        reason: 'file-hash-mismatch',
      );
    }
    return const IntegrityResult.passed();
  } catch (e) {
    // อ่านไฟล์/parse ล้มเหลวแบบไม่คาดคิด → ข้าม (อย่าล็อกผู้ใช้ผิดพลาด)
    return IntegrityResult.skipped('verify-error:${e.runtimeType}');
  }
}

/// สร้างสตริง canonical จาก map ของไฟล์ (เรียงคีย์) เพื่อเซ็น/ตรวจให้คงที่
String _canonicalFiles(Map<dynamic, dynamic> files) {
  final keys = files.keys.map((e) => e.toString()).toList()..sort();
  final buffer = StringBuffer();
  for (final k in keys) {
    buffer.write(k);
    buffer.write('=');
    buffer.write(files[k].toString().toLowerCase());
    buffer.write(';');
  }
  return buffer.toString();
}

Future<String> _sha256OfFile(File file) async {
  final bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString().toLowerCase();
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
