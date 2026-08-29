import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:saccm/core/services/secure_credential_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saccm/features/license/data/datasources/license_local_data_source.dart';
import 'package:saccm/features/license/data/datasources/license_remote_data_source.dart';

/// จัดการ JWT session สำหรับ sync กับ server กลาง
class SessionTokenService {
  SessionTokenService._();

  static const String tokenKey = 'token';
  static const String lastUsernameKey = 'last_username';

  static bool isServerJwt(String? token) =>
      token != null && token.isNotEmpty && !token.startsWith('local_');

  static Future<String?> readToken() async {
    return SecureCredentialStore.read(tokenKey);
  }

  static Future<String?> readLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastUsernameKey);
  }

  static Future<void> saveServerToken(String token, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await SecureCredentialStore.write(tokenKey, token);
    await prefs.setString(lastUsernameKey, username);
  }

  static Future<void> saveLocalToken(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await SecureCredentialStore.write(tokenKey, 'local_$username');
    await prefs.setString(lastUsernameKey, username);
  }

  static Future<void> clearToken() async {
    await SecureCredentialStore.delete(tokenKey);
  }

  /// หมดอายุแล้ว หรือเหลือเวลาน้อยกว่า [margin]
  static bool isExpiredOrNearExpiry(
    String token, {
    Duration margin = const Duration(minutes: 30),
  }) {
    try {
      if (JwtDecoder.isExpired(token)) return true;
      final expiry = JwtDecoder.getExpirationDate(token);
      return expiry.difference(DateTime.now()) < margin;
    } catch (_) {
      return true;
    }
  }

  /// ขอ JWT ใหม่จาก server (ต้องมี school ที่ activate แล้ว)
  static Future<String?> fetchFreshToken({
    required String username,
    required String password,
  }) async {
    final license = await LicenseLocalDataSource().loadLicenseInfo();
    if (license == null) return null;

    return LicenseRemoteDataSource().fetchServerToken(
      schoolCode: license.schoolCode,
      username: username,
      password: password,
    );
  }

  /// รีเฟรชถ้าใกล้หมดอายุ — คืน true ถ้ามี JWT ที่ใช้ได้
  static Future<bool> refreshIfNeeded({
    required String username,
    String? password,
  }) async {
    final current = await readToken();
    if (isServerJwt(current) && !isExpiredOrNearExpiry(current!)) {
      return true;
    }

    final pwd = password;
    if (pwd == null || pwd.length < 6) return isServerJwt(current);

    final fresh = await fetchFreshToken(
      username: username,
      password: pwd,
    );
    if (fresh != null && fresh.isNotEmpty) {
      await saveServerToken(fresh, username);
      return true;
    }
    return isServerJwt(current);
  }
}
