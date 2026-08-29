import 'package:shared_preferences/shared_preferences.dart';

// trailing slash required: remote data sources use '${baseurl}income' etc.
//
// Override at build/run:
//   --dart-define=SACC_API_BASE=http://host:port/saccapi/
//   --dart-define=SACC_REGISTRY_BASE=http://host:3802/registryapi/

class RuntimeConfig {
  RuntimeConfig._();

  static const apiUrlPrefsKey = 'api_url';
  static const _defaultApiBase = String.fromEnvironment(
    'SACC_API_BASE',
    defaultValue: 'https://ktdevelop.com/saccapi/',
  );
  static const _defaultRegistryBase = String.fromEnvironment(
    'SACC_REGISTRY_BASE',
    defaultValue: 'https://ktdevelop.com/registryapi/',
  );

  static String _apiBaseUrl = normalizeApiBase(_defaultApiBase);
  static String _registryBaseUrl = normalizeRegistryBase(_defaultRegistryBase);

  static String get apiBaseUrl => _apiBaseUrl;
  static String get registryBaseUrl => _registryBaseUrl;

  static Future<void> loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBaseUrl = normalizeApiBase(
      prefs.getString(apiUrlPrefsKey) ?? _defaultApiBase,
    );
    _registryBaseUrl = normalizeRegistryBase(_defaultRegistryBase);
  }

  static Future<void> setApiBaseUrl(String value) async {
    final normalized = normalizeApiBase(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiUrlPrefsKey, normalized);
    _apiBaseUrl = normalized;
  }

  static Future<void> resetApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(apiUrlPrefsKey);
    _apiBaseUrl = normalizeApiBase(_defaultApiBase);
  }

  static String normalizeApiBase(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return normalizeApiBase(_defaultApiBase);
    final noSlash = trimmed.replaceFirst(RegExp(r'/+$'), '');
    if (noSlash.endsWith('/saccapi')) return '$noSlash/';
    return '$noSlash/saccapi/';
  }

  static String normalizeRegistryBase(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return normalizeRegistryBase(_defaultRegistryBase);
    final noSlash = trimmed.replaceFirst(RegExp(r'/+$'), '');
    if (noSlash.endsWith('/registryapi')) return '$noSlash/';
    return '$noSlash/registryapi/';
  }
}

String get baseurl => RuntimeConfig.apiBaseUrl;

/// Registry กลาง — keygen log, activate, license (แยกจาก API ออนไลน์)
String get registryBase => RuntimeConfig.registryBaseUrl;

/// จำนวนวันทดลองใช้บนเครื่อง — ไม่ผ่าน Registry
const int kEmbeddedTrialDays = 90;
