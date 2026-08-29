import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureCredentialStore {
  SecureCredentialStore._();

  static const Duration _ioTimeout = Duration(seconds: 8);

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(),
  );

  /// คิวเดียว — กันเรียก FlutterSecureStorage พร้อมกันบน Windows (มักค้าง/deadlock)
  static var _opChain = Future<void>.value();

  static Future<T> _serialized<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _opChain = _opChain.then((_) async {
      try {
        result.complete(await action());
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  static Future<String?> read(
    String key, {
    SharedPreferences? legacyPrefs,
  }) async {
    return _serialized(() async {
      String? secureValue;
      try {
        secureValue = await _storage
            .read(key: key)
            .timeout(_ioTimeout, onTimeout: () => null);
      } catch (_) {
        secureValue = null;
      }
      if (secureValue != null && secureValue.isNotEmpty) return secureValue;

      final prefs = legacyPrefs ?? await SharedPreferences.getInstance();
      final legacyValue = prefs.getString(key);
      if (legacyValue != null && legacyValue.isNotEmpty) {
        try {
          await _storage
              .write(key: key, value: legacyValue)
              .timeout(_ioTimeout);
          await prefs.remove(key);
        } catch (_) {
          // ยังคืนค่า legacy ได้แม้ migrate เข้า secure storage ไม่สำเร็จ
        }
      }
      return legacyValue;
    });
  }

  static Future<void> write(String key, String value) async {
    await _serialized(() async {
      try {
        await _storage.write(key: key, value: value).timeout(_ioTimeout);
      } catch (_) {
        // ยังลบ legacy ออกเพื่อไม่ให้ค่าค้างซ้ำสองที่
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    });
  }

  static Future<void> delete(String key) async {
    await _serialized(() async {
      try {
        await _storage.delete(key: key).timeout(_ioTimeout);
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    });
  }
}
