import 'data/datasources/license_local_data_source.dart';
import 'data/datasources/license_remote_data_source.dart';
import 'embedded_trial_license.dart';
import 'product_tier.dart';

/// สถานะแพ็กเกจปัจจุบัน
class LicenseSnapshot {
  final ProductTier tier;
  final EmbeddedTrialStatus? trial;
  final DateTime? licenseExpiresAt;
  final String? schoolName;

  const LicenseSnapshot({
    required this.tier,
    this.trial,
    this.licenseExpiresAt,
    this.schoolName,
  });

  bool get isLicenseExpired =>
      tier.isLicensed &&
      licenseExpiresAt != null &&
      licenseExpiresAt!.isBefore(DateTime.now());

  bool get isTrialExpired =>
      tier == ProductTier.trial && (trial?.expired ?? false);

  bool get canUseApp {
    if (tier.isLicensed) {
      if (isLicenseExpired) return false;
      return true;
    }
    return tier == ProductTier.trial && !isTrialExpired;
  }

  bool get canSyncOnline =>
      tier.canSyncOnline && tier.isLicensed && !isLicenseExpired;
}

class LicenseMode {
  LicenseMode._();

  static final LicenseLocalDataSource _local = LicenseLocalDataSource();

  /// ลงทะเบียนด้วยรหัสแล้ว (ออฟไลน์หรือออนไลน์)
  static Future<bool> isLicensed() async {
    final tier = await _local.getProductTier();
    return tier?.isLicensed ?? false;
  }

  /// ซิงก์กับ server กลางได้ (แพ็กเกจออนไลน์+ออฟไลน์)
  static Future<bool> canSyncOnline() async {
    return (await snapshot()).canSyncOnline;
  }

  /// @deprecated ใช้ [isLicensed] หรือ [canSyncOnline]
  static Future<bool> isOnlineRegistered() => isLicensed();

  static Future<bool> isEmbeddedTrialActive() =>
      EmbeddedTrialLicense.isActive();

  static Future<bool> canUseApp() async {
    return (await snapshot()).canUseApp;
  }

  /// ตรวจกับ Registry เมื่อมีเน็ต (แพ็กเกจ online)
  static Future<void> revalidateLicensedOnlineIfPossible() async {
    if (!await canSyncOnline()) return;
    final info = await _local.loadLicenseInfo();
    if (info == null) return;
    try {
      final status = await LicenseRemoteDataSource().fetchStatus(
        schoolCode: info.schoolCode,
        deviceId: info.deviceId,
      );
      if (status.expired || status.licenseStatus == 'revoked') {
        await _local.markLicenseExpired();
      }
    } catch (_) {}
  }

  static Future<EmbeddedTrialStatus> embeddedTrialStatus() =>
      EmbeddedTrialLicense.status();

  static Future<LicenseSnapshot> snapshot() async {
    final licensedTier = await _local.getProductTier();
    if (licensedTier != null && licensedTier.isLicensed) {
      final info = await _local.loadLicenseInfo();
      return LicenseSnapshot(
        tier: licensedTier,
        licenseExpiresAt: await _local.getExpiresAt(),
        schoolName: info?.schoolName,
      );
    }

    final trial = await EmbeddedTrialLicense.status();
    return LicenseSnapshot(
      tier: ProductTier.trial,
      trial: trial,
    );
  }
}
