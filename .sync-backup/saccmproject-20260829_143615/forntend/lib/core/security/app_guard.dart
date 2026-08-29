import 'package:flutter/foundation.dart';

import 'anti_debug.dart';
import 'binary_integrity.dart';

/// ผลรวมของการตรวจระบบกันแกะโค๊ดตอนเปิดแอป
enum GuardVerdict {
  /// ผ่าน — เปิดแอปได้ตามปกติ
  ok,

  /// ตรวจพบไฟล์โปรแกรมถูกแก้ไข (integrity ไม่ผ่าน)
  tampered,

  /// ตรวจพบ debugger/เครื่องมือแกะโปรแกรม
  debuggerDetected,
}

/// ตัวจัดการระบบกันแกะโค๊ด (anti-tamper orchestrator)
///
/// รวมการตรวจหลายชั้นไว้ที่เดียว เรียกครั้งเดียวตอน bootstrap:
///  1. integrity ของไฟล์ binary (เทียบ manifest ที่เซ็นตอน build)
///  2. ตรวจ debugger ที่แนบกับ process (Windows)
///
/// ปรัชญา fail-safe: ถ้าตรวจไม่ได้/ข้าม (debug build, ไม่มี manifest) จะ
/// "ไม่บล็อก" เพื่อไม่ให้ผู้ใช้จริงเดือดร้อนจาก false positive — บล็อกเฉพาะ
/// เมื่อ "พบหลักฐานชัดเจน" ว่าถูกแก้ไขหรือถูกแกะเท่านั้น
class AppGuard {
  AppGuard._();

  static GuardVerdict _lastVerdict = GuardVerdict.ok;

  /// ผลการตรวจครั้งล่าสุด (ใช้โดย UI gate)
  static GuardVerdict get lastVerdict => _lastVerdict;

  /// รันการตรวจทั้งหมด คืนคำตัดสินรวม
  static Future<GuardVerdict> run() async {
    // ข้ามทั้งหมดใน debug เพื่อความสะดวกตอนพัฒนา
    if (kDebugMode) {
      _lastVerdict = GuardVerdict.ok;
      return _lastVerdict;
    }

    // 1) integrity ของไฟล์ binary
    final integrity = await verifyBinaryIntegrity();
    if (!integrity.ok && !integrity.skipped) {
      _lastVerdict = GuardVerdict.tampered;
      return _lastVerdict;
    }

    // 2) anti-debug
    if (isDebuggerAttached()) {
      _lastVerdict = GuardVerdict.debuggerDetected;
      return _lastVerdict;
    }

    _lastVerdict = GuardVerdict.ok;
    return _lastVerdict;
  }

  /// ตรวจ debugger ซ้ำระหว่างรัน (เรียกเป็นระยะจาก UI gate)
  /// คืน true ถ้าพบ debugger ที่เพิ่งแนบเข้ามาภายหลัง
  static bool recheckDebugger() {
    if (kDebugMode) return false;
    if (isDebuggerAttached()) {
      _lastVerdict = GuardVerdict.debuggerDetected;
      return true;
    }
    return false;
  }
}
