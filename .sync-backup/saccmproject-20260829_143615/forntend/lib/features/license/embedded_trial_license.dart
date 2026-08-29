import 'package:saccm/config.dart';
import 'package:saccm/core/services/device_fingerprint.dart';
import 'package:saccm/core/services/redundant_local_store.dart';
import 'package:saccm/features/license/data/datasources/license_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// คีย์เดิม (plain SharedPreferences) — เก็บไว้เพื่อ migrate ของเดิม
const String _legacyTrialStartedAtKey = 'embedded_trial_started_at';

const int _dayMs = Duration.millisecondsPerDay;

/// สถานะทดลองใช้บนเครื่อง
class EmbeddedTrialStatus {
  final DateTime startedAt;
  final DateTime expiresAt;
  final int daysTotal;
  final int daysRemaining;
  final bool expired;

  const EmbeddedTrialStatus({
    required this.startedAt,
    required this.expiresAt,
    required this.daysTotal,
    required this.daysRemaining,
    required this.expired,
  });
}

/// ทดลองใช้บนเครื่อง — ไม่ต้องลงทะเบียน Registry
///
/// Tier A (local hardening):
///  - เก็บวันเริ่ม/last_seen แบบ redundant (secure storage + ไฟล์ anchor)
///    ลบที่เดียวไม่พอ reset
///  - กันตั้งนาฬิกาถอยหลัง (monotonic last_seen)
///
/// Tier B (server-anchored):
///  - anchor วันเริ่มกับ Registry ตาม device fingerprint
///    กัน reset/reinstall (เมื่อ fingerprint คงที่) — ใช้วันหมดอายุที่
///    "เร็วกว่า" ระหว่าง local กับ server เสมอ
class EmbeddedTrialLicense {
  EmbeddedTrialLicense._();

  static final RedundantLocalStore _store = RedundantLocalStore('saccm_trial');

  static const String _startedAtKey = 'started_at';
  static const String _lastSeenKey = 'last_seen';
  static const String _serverExpiresKey = 'server_expires_at';
  static const String _serverStartedKey = 'server_started_at';
  static const String _serverSignatureKey = 'server_signature';

  static DateTime? _parse(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw);

  static DateTime _earliest(Iterable<DateTime> values) =>
      values.reduce((a, b) => a.isBefore(b) ? a : b);

  /// บันทึกวันเริ่มทดลอง (ครั้งแรกเท่านั้น) แล้วคืนวันเริ่มที่ "เก่าที่สุด"
  static Future<DateTime> ensureStarted() async {
    final candidates = <DateTime>[];

    for (final raw in await _store.readAll(_startedAtKey)) {
      final parsed = _parse(raw);
      if (parsed != null) candidates.add(parsed);
    }

    // migrate ค่าจากคีย์เดิม
    final prefs = await SharedPreferences.getInstance();
    final legacy = _parse(prefs.getString(_legacyTrialStartedAtKey));
    if (legacy != null) candidates.add(legacy);

    if (candidates.isNotEmpty) {
      final earliest = _earliest(candidates);
      // self-heal: เขียนค่าเดิมกลับทุก anchor ที่หายไป
      await _store.reinforce(_startedAtKey, earliest.toIso8601String());
      return earliest;
    }

    final now = DateTime.now();
    await _store.write(_startedAtKey, now.toIso8601String());
    return now;
  }

  /// เวลาปัจจุบันแบบกันนาฬิกาถอยหลัง (ไม่ให้ remaining เพิ่มขึ้นเอง)
  static Future<DateTime> _monotonicNow() async {
    final now = DateTime.now();
    DateTime seen = now;
    for (final raw in await _store.readAll(_lastSeenKey)) {
      final parsed = _parse(raw);
      if (parsed != null && parsed.isAfter(seen)) seen = parsed;
    }
    // last_seen เพิ่มขึ้นอย่างเดียว
    await _store.reinforce(_lastSeenKey, seen.toIso8601String());
    return seen;
  }

  static Future<EmbeddedTrialStatus> status() async {
    final startedAt = await ensureStarted();
    final now = await _monotonicNow();

    final localExpiry = startedAt.add(const Duration(days: kEmbeddedTrialDays));
    final serverExpiry = _parse(await _store.readFirst(_serverExpiresKey));

    // ใช้วันหมดอายุที่ "เร็วกว่า" เสมอ — กันทั้ง local และ cache server ถูกแก้ให้ยืดเวลา
    final expiresAt =
        (serverExpiry != null && serverExpiry.isBefore(localExpiry))
            ? serverExpiry
            : localExpiry;

    final remainingMs = expiresAt.difference(now).inMilliseconds;
    final daysRemaining = remainingMs <= 0 ? 0 : (remainingMs / _dayMs).ceil();

    return EmbeddedTrialStatus(
      startedAt: startedAt,
      expiresAt: expiresAt,
      daysTotal: kEmbeddedTrialDays,
      daysRemaining: daysRemaining,
      expired: now.isAfter(expiresAt),
    );
  }

  static Future<bool> isActive() async {
    final s = await status();
    return !s.expired;
  }

  /// Tier B — anchor วันเริ่มกับ Registry เมื่อมีเน็ต (เรียกแบบ background)
  /// ปลอดภัยที่จะเรียกซ้ำ: server คืนวันเริ่มเดิมเสมอ
  static Future<void> syncServerAnchorIfPossible() async {
    try {
      final fingerprint = await DeviceFingerprint.get();
      final result =
          await LicenseRemoteDataSource().startTrial(fingerprint: fingerprint);
      if (result == null) return;

      await _store.write(_serverExpiresKey, result.expiresAt.toIso8601String());
      await _store.write(_serverStartedKey, result.startedAt.toIso8601String());
      if (result.signature != null) {
        await _store.write(_serverSignatureKey, result.signature!);
      }

      // ถ้า server รู้วันเริ่มที่เก่ากว่า (เช่นหลัง reinstall) ให้ดึงลง local ด้วย
      final localStarted = await ensureStarted();
      if (result.startedAt.isBefore(localStarted)) {
        await _store.reinforce(
          _startedAtKey,
          result.startedAt.toIso8601String(),
        );
      }
    } catch (_) {
      // ออฟไลน์/Registry ล่ม → ใช้ค่า local ต่อไป
    }
  }
}
