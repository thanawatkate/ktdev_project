import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'redundant_local_store.dart';

/// fingerprint ของเครื่องสำหรับ anchor วันทดลองใช้กับ Registry (Tier B/C)
///
/// - Windows/Linux/macOS/iOS: ใช้ค่า hardware ที่คงที่ข้าม reinstall
///   (MachineGuid / machineId / systemGUID / identifierForVendor)
/// - Android / Web: ไม่มี hardware id ที่คงที่ข้าม reinstall →
///   fallback เป็น install id ที่เก็บแบบ redundant (กัน clear app data
///   ได้ แต่ reinstall จะได้ค่าใหม่)
class DeviceFingerprint {
  DeviceFingerprint._();

  static final RedundantLocalStore _store =
      RedundantLocalStore('saccm_device');
  static const String _installIdKey = 'install_id';
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final hardware = await _hardwareSignal();
    final basis = (hardware != null && hardware.trim().isNotEmpty)
        ? 'hw:${hardware.trim()}'
        : 'sw:${await _installId()}';
    _cached = sha256.convert(utf8.encode(basis)).toString();
    return _cached!;
  }

  static Future<String> _installId() async {
    final existing = await _store.readFirst(_installIdKey);
    if (existing != null && existing.isNotEmpty) {
      await _store.reinforce(_installIdKey, existing);
      return existing;
    }
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final id = sha256.convert(bytes).toString();
    await _store.write(_installIdKey, id);
    return id;
  }

  static Future<String?> _hardwareSignal() async {
    if (kIsWeb) return null;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isWindows) return (await info.windowsInfo).deviceId;
      if (Platform.isLinux) return (await info.linuxInfo).machineId;
      if (Platform.isMacOS) return (await info.macOsInfo).systemGUID;
      if (Platform.isIOS) return (await info.iosInfo).identifierForVendor;
      // Android: ไม่มี stable hardware id → ใช้ install id แทน
      return null;
    } catch (_) {
      return null;
    }
  }
}
