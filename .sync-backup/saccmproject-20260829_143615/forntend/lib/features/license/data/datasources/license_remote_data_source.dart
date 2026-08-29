import 'package:dio/dio.dart';
import 'package:saccm/config.dart';
import 'package:saccm/core/platform/runtime_platform.dart';
import 'package:saccm/features/license/data/models/license_validate_preview.dart';
import 'package:saccm/features/license/product_tier.dart';

class LicenseActivationResult {
  final String schoolCode;
  final String schoolName;
  final String token;
  final String adminUsername;
  final String? licenseKind;
  final bool canSync;
  final DateTime? expiresAt;

  const LicenseActivationResult({
    required this.schoolCode,
    required this.schoolName,
    required this.token,
    required this.adminUsername,
    this.licenseKind,
    this.canSync = false,
    this.expiresAt,
  });

  ProductTier? get productTier => ProductTierX.fromRegistryKind(licenseKind);
}

/// ผลลัพธ์ anchor วันทดลองใช้จาก Registry (Tier B)
class TrialAnchorResult {
  final DateTime startedAt;
  final DateTime expiresAt;
  final int days;
  final bool expired;
  final String? signature;

  const TrialAnchorResult({
    required this.startedAt,
    required this.expiresAt,
    required this.days,
    required this.expired,
    this.signature,
  });
}

class LicenseStatusResult {
  final String schoolCode;
  final String schoolName;
  final String licenseStatus;
  final String? licenseKind;
  final bool expired;
  final int devicesUsed;
  final int maxDevices;
  final bool thisDeviceRegistered;
  final bool canSync;
  final DateTime? expiresAt;

  const LicenseStatusResult({
    required this.schoolCode,
    required this.schoolName,
    required this.licenseStatus,
    this.licenseKind,
    required this.expired,
    required this.devicesUsed,
    required this.maxDevices,
    required this.thisDeviceRegistered,
    required this.canSync,
    this.expiresAt,
  });

  factory LicenseStatusResult.fromJson(Map<String, dynamic> data) {
    DateTime? exp;
    final raw = data['expiresAt'];
    if (raw != null) {
      exp = DateTime.tryParse(raw.toString());
    }
    return LicenseStatusResult(
      schoolCode: data['schoolCode'] as String? ?? '',
      schoolName: data['schoolName'] as String? ?? '',
      licenseStatus: data['licenseStatus'] as String? ?? '',
      licenseKind: data['licenseKind'] as String?,
      expired: data['expired'] == true,
      devicesUsed: (data['devicesUsed'] as num?)?.toInt() ?? 0,
      maxDevices: (data['maxDevices'] as num?)?.toInt() ?? 0,
      thisDeviceRegistered: data['thisDeviceRegistered'] == true,
      canSync: data['canSync'] == true,
      expiresAt: exp,
    );
  }
}

class LicenseAdminRow {
  final int id;
  final String schoolCode;
  final String schoolName;
  final String status;
  final String? licenseKind;
  final int maxDevices;
  final int devicesUsed;
  final String? expiresAt;
  final String? keyHint;
  final String? issuedBy;

  const LicenseAdminRow({
    required this.id,
    required this.schoolCode,
    required this.schoolName,
    required this.status,
    this.licenseKind,
    required this.maxDevices,
    required this.devicesUsed,
    this.expiresAt,
    this.keyHint,
    this.issuedBy,
  });

  factory LicenseAdminRow.fromJson(Map<String, dynamic> j) {
    return LicenseAdminRow(
      id: (j['id'] as num).toInt(),
      schoolCode:
          j['school_code'] as String? ?? j['schoolCode'] as String? ?? '',
      schoolName:
          j['school_name'] as String? ?? j['schoolName'] as String? ?? '',
      status: j['status'] as String? ?? '',
      licenseKind: j['license_kind'] as String? ?? j['licenseKind'] as String?,
      maxDevices: (j['max_devices'] as num?)?.toInt() ??
          (j['maxDevices'] as num?)?.toInt() ??
          0,
      devicesUsed: (j['devicesUsed'] as num?)?.toInt() ?? 0,
      expiresAt: j['expires_at']?.toString() ?? j['expiresAt']?.toString(),
      keyHint: j['key_hint'] as String? ?? j['keyHint'] as String?,
      issuedBy: j['issued_by'] as String? ?? j['issuedBy'] as String?,
    );
  }
}

class LicenseRemoteDataSource {
  final Dio dio;

  LicenseRemoteDataSource({Dio? dio}) : dio = dio ?? Dio();

  String get _registryRoot {
    final b = registryBase.endsWith('/') ? registryBase : '$registryBase/';
    return b;
  }

  /// ตรวจว่า Registry ตอบ (ใช้ก่อน activate)
  Future<bool> isRegistryReachable() async {
    try {
      final response = await dio.get(
        _registryRoot,
        options: Options(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      return (response.statusCode ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _adminHeaders(String adminSecret) => {
        'Content-Type': 'application/json',
        'X-License-Admin-Secret': adminSecret,
      };

  Future<LicenseActivationResult> activate({
    required String licenseKey,
    required String deviceId,
    required String deviceLabel,
    required String adminUsername,
    required String adminPassword,
    required String adminName,
    required String adminLastname,
    String adminEmail = '',
  }) async {
    final response = await dio.post(
      '${_registryRoot}license/activate',
      data: {
        'licenseKey': licenseKey.trim(),
        'deviceId': deviceId,
        'deviceLabel': deviceLabel,
        'platform': runtimePlatformId,
        'adminUsername': adminUsername.trim(),
        'adminPassword': adminPassword,
        'adminName': adminName.trim(),
        'adminLastname': adminLastname.trim(),
        'adminEmail': adminEmail.trim(),
      },
      options: Options(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    final data = response.data;
    if (response.statusCode != 200 || data['status'] != 'success') {
      throw Exception(data['message']?.toString() ?? 'เปิดใช้งานไม่สำเร็จ');
    }

    DateTime? exp;
    if (data['expiresAt'] != null) {
      exp = DateTime.tryParse(data['expiresAt'].toString());
    }

    return LicenseActivationResult(
      schoolCode: data['schoolCode'] as String,
      schoolName: data['schoolName'] as String,
      token: (data['token'] as String?) ?? '',
      adminUsername: data['adminUsername'] as String,
      licenseKind: data['licenseKind'] as String?,
      canSync: data['canSync'] == true,
      expiresAt: exp,
    );
  }

  Future<String?> fetchServerToken({
    required String schoolCode,
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '${_registryRoot}license/token',
      data: {
        'schoolCode': schoolCode.trim(),
        'username': username.trim(),
        'password': password,
      },
      options: Options(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final data = response.data;
    if (response.statusCode != 200 || data is! Map) return null;
    if (data['status'] != null && data['status'] != 'success') return null;
    return (data['token'] ?? data['accessToken'])?.toString();
  }

  Future<LicenseValidatePreview?> validateKey(String licenseKey) async {
    final response = await dio.post(
      '${_registryRoot}license/validate',
      data: {'licenseKey': licenseKey.trim()},
      options: Options(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    final data = response.data as Map<String, dynamic>;
    if (data['status'] != 'success' || data['valid'] != true) {
      return null;
    }
    final kind = data['licenseKind'] as String?;
    return LicenseValidatePreview(
      schoolName: data['schoolName'] as String? ?? '',
      productTier: ProductTierX.fromRegistryKind(kind),
      expired: data['expired'] == true,
    );
  }

  Future<void> sendHeartbeat({
    required String schoolCode,
    required String deviceId,
  }) async {
    await dio.post(
      '${_registryRoot}license/heartbeat',
      data: {
        'schoolCode': schoolCode,
        'deviceId': deviceId,
        'platform': runtimePlatformId,
      },
      options: Options(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  /// Tier B — anchor วันเริ่มทดลองใช้กับ Registry ตาม fingerprint ของเครื่อง
  Future<TrialAnchorResult?> startTrial({
    required String fingerprint,
  }) async {
    final response = await dio.post(
      '${_registryRoot}trial/start',
      data: {
        'fingerprint': fingerprint,
        'platform': runtimePlatformId,
      },
      options: Options(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final data = response.data;
    if (response.statusCode != 200 ||
        data is! Map ||
        data['status'] != 'success') {
      return null;
    }
    final startedAt = DateTime.tryParse(data['startedAt']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
    if (startedAt == null || expiresAt == null) return null;
    return TrialAnchorResult(
      startedAt: startedAt,
      expiresAt: expiresAt,
      days: (data['days'] as num?)?.toInt() ?? 0,
      expired: data['expired'] == true,
      signature: data['signature']?.toString(),
    );
  }

  Future<LicenseStatusResult> fetchStatus({
    required String schoolCode,
    required String deviceId,
  }) async {
    final response = await dio.post(
      '${_registryRoot}license/status',
      data: {'schoolCode': schoolCode, 'deviceId': deviceId},
      options: Options(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    final data = response.data as Map<String, dynamic>;
    if (response.statusCode != 200 || data['status'] != 'success') {
      throw Exception(data['message']?.toString() ?? 'โหลดสถานะไม่สำเร็จ');
    }
    return LicenseStatusResult.fromJson(data);
  }

  Future<List<LicenseAdminRow>> listLicensesAdmin(String adminSecret) async {
    final response = await dio.get(
      '${_registryRoot}license/admin/list',
      options: Options(headers: _adminHeaders(adminSecret)),
    );
    final data = response.data as Map<String, dynamic>;
    if (response.statusCode != 200 || data['status'] != 'success') {
      throw Exception(data['message']?.toString() ?? 'โหลดรายการไม่สำเร็จ');
    }
    final rows = data['rows'] as List<dynamic>? ?? [];
    return rows
        .map((e) => LicenseAdminRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> generateLicenseAdmin({
    required String adminSecret,
    required String schoolName,
    int maxDevices = 5,
    int expiresInDays = 365,
    ProductTier productTier = ProductTier.offline,
  }) async {
    final kind = productTier == ProductTier.online ? 'online' : 'offline';
    final response = await dio.post(
      '${_registryRoot}license/admin/generate',
      data: {
        'schoolName': schoolName,
        'maxDevices': maxDevices,
        'expiresInDays': expiresInDays,
        'licenseKind': kind,
      },
      options: Options(headers: _adminHeaders(adminSecret)),
    );
    final data = response.data as Map<String, dynamic>;
    if (data['status'] != 'success') {
      throw Exception(data['message']?.toString() ?? 'สร้างรหัสไม่สำเร็จ');
    }
    return data['licenseKey'] as String;
  }

  Future<List<Map<String, dynamic>>> listIssueLogsAdmin(
      String adminSecret) async {
    final response = await dio.get(
      '${_registryRoot}license/admin/issue-logs',
      options: Options(headers: _adminHeaders(adminSecret)),
    );
    final data = response.data as Map<String, dynamic>;
    if (data['status'] != 'success') {
      throw Exception(data['message']?.toString() ?? 'โหลดบันทึกไม่สำเร็จ');
    }
    return (data['rows'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listActivationLogsAdmin(
      String adminSecret) async {
    final response = await dio.get(
      '${_registryRoot}license/admin/activation-logs',
      options: Options(headers: _adminHeaders(adminSecret)),
    );
    final data = response.data as Map<String, dynamic>;
    if (data['status'] != 'success') {
      throw Exception(data['message']?.toString() ?? 'โหลดบันทึกไม่สำเร็จ');
    }
    return (data['rows'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> revokeLicenseAdmin({
    required String adminSecret,
    required String schoolCode,
    String? note,
  }) async {
    final response = await dio.post(
      '${_registryRoot}license/admin/revoke',
      data: {'schoolCode': schoolCode, if (note != null) 'note': note},
      options: Options(headers: _adminHeaders(adminSecret)),
    );
    final data = response.data as Map<String, dynamic>;
    if (response.statusCode != 200 || data['status'] != 'success') {
      throw Exception(data['message']?.toString() ?? 'ยกเลิกไม่สำเร็จ');
    }
  }
}
