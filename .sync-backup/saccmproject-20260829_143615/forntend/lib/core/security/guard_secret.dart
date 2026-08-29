import 'dart:convert';

import 'package:crypto/crypto.dart';

/// ความลับฝังในแอป (embedded secrets) สำหรับระบบกันแกะโค๊ด
///
/// แนวป้องกัน: ค่าพวกนี้ถูกซ่อนด้วย Dart obfuscation (`--obfuscate`) ตอน
/// build release จึงอ่านยากจาก binary; ระดับภัยคุกคามคือกัน "แกะ/แก้แบบทั่วไป"
/// ไม่ใช่กันผู้โจมตีที่มีทรัพยากรไม่จำกัด
///
/// สำคัญ:
///  - [integritySecretHex] ต้องตรงกับค่าใน `tool/build_windows_protected.ps1`
///    เพราะ manifest ตรวจความถูกต้องของไฟล์ถูกเซ็นด้วยคีย์เดียวกัน
///  - เปลี่ยนค่าพวกนี้เมื่อไรต้อง rebuild + สร้าง manifest ใหม่เสมอ
class GuardSecret {
  GuardSecret._();

  /// คีย์เซ็นค่าใน local store (trial/license anchor) — กันแก้ไฟล์
  static const String storeSecretHex =
      'a3f1c08e7b29d64f5c1e0b8a4d7f3e92c6b50a1d9f8273e4c5a6b7d8e9f001122';

  /// คีย์เซ็น integrity manifest ของไฟล์ binary — ต้องตรงกับ build script
  static const String integritySecretHex =
      '7c4e91a2b3d65f08e1c2a4b6d8f0e2c4a6b8d0f2e4c6a8b0d2f4e6c8a0b2d4f6';

  static List<int> _hexToBytes(String hex) {
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  /// HMAC-SHA256 (hex) สำหรับเซ็นค่าใน local store
  static String signStoreValue(String payload) {
    final mac = Hmac(sha256, _hexToBytes(storeSecretHex));
    return mac.convert(utf8.encode(payload)).toString();
  }

  /// HMAC-SHA256 (hex) สำหรับตรวจ integrity manifest
  static String signIntegrity(String payload) {
    final mac = Hmac(sha256, _hexToBytes(integritySecretHex));
    return mac.convert(utf8.encode(payload)).toString();
  }
}
