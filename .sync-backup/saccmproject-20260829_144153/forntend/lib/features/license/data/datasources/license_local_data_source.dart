import 'dart:math';

import 'package:saccm/core/services/secure_credential_store.dart';
import 'package:saccm/features/license/product_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseInfo {
  final String schoolCode;
  final String schoolName;
  final String deviceId;

  const LicenseInfo({
    required this.schoolCode,
    required this.schoolName,
    required this.deviceId,
  });
}

class LicenseLocalDataSource {
  static const _activatedKey = 'license_activated';
  static const _schoolCodeKey = 'school_code';
  static const _schoolNameKey = 'school_name';
  static const _deviceIdKey = 'device_id';
  static const _productTierKey = 'product_tier';
  static const _licenseKindKey = 'license_kind';
  static const _expiresAtKey = 'license_expires_at';
  static const _adminSecretKey = 'license_admin_secret';

  Future<bool> isActivated() async {
    final tier = await getProductTier();
    return tier?.isLicensed ?? false;
  }

  Future<ProductTier?> getProductTier() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activatedKey) ?? false)) return null;
    if (prefs.getString(_productTierKey) == 'expired') return null;
    final fromTier = ProductTierX.fromStorage(prefs.getString(_productTierKey));
    if (fromTier != null) return fromTier;
    return ProductTierX.fromRegistryKind(prefs.getString(_licenseKindKey));
  }

  Future<LicenseInfo?> loadLicenseInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activatedKey) ?? false)) return null;
    final schoolCode = prefs.getString(_schoolCodeKey);
    final schoolName = prefs.getString(_schoolNameKey);
    final deviceId = prefs.getString(_deviceIdKey);
    if (schoolCode == null || schoolName == null || deviceId == null) {
      return null;
    }
    return LicenseInfo(
      schoolCode: schoolCode,
      schoolName: schoolName,
      deviceId: deviceId,
    );
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<void> saveActivation({
    required String schoolCode,
    required String schoolName,
    required String deviceId,
    required String token,
    required String adminUsername,
    String? licenseKind,
    ProductTier? productTier,
    DateTime? expiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final tier = productTier ?? ProductTierX.fromRegistryKind(licenseKind);
    await prefs.setBool(_activatedKey, true);
    await prefs.setString(_schoolCodeKey, schoolCode);
    await prefs.setString(_schoolNameKey, schoolName);
    await prefs.setString(_deviceIdKey, deviceId);
    if (token.isNotEmpty) {
      await SecureCredentialStore.write('token', token);
    } else {
      await SecureCredentialStore.delete('token');
    }
    await prefs.setString('last_username', adminUsername);
    if (tier != null) {
      await prefs.setString(_productTierKey, tier.storageKey);
    }
    if (licenseKind != null) {
      await prefs.setString(_licenseKindKey, licenseKind);
    }
    if (expiresAt != null) {
      await prefs.setString(_expiresAtKey, expiresAt.toIso8601String());
    }
  }

  Future<String?> getLicenseKind() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseKindKey);
  }

  Future<DateTime?> getExpiresAt() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_expiresAtKey);
    return s == null ? null : DateTime.tryParse(s);
  }

  Future<String?> getAdminSecret() async {
    return SecureCredentialStore.read(_adminSecretKey);
  }

  /// บันทึกว่าหมดอายุ/ถูกยกเลิก (ยังเก็บข้อมูลโรงเรียนไว้แสดงในหน้าแผน)
  Future<void> markLicenseExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKindKey, 'expired');
    await prefs.setString(_productTierKey, 'expired');
  }

  Future<bool> isMarkedExpired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_productTierKey) == 'expired';
  }

  Future<void> saveAdminSecret(String secret) async {
    final trimmed = secret.trim();
    if (trimmed.isEmpty) {
      await SecureCredentialStore.delete(_adminSecretKey);
    } else {
      await SecureCredentialStore.write(_adminSecretKey, trimmed);
    }
  }
}
