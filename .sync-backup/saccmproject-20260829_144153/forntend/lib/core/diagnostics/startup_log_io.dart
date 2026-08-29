import 'dart:io';

/// Append-only startup trace for diagnosing crash-on-launch (e.g. low RAM).
///
/// Windows: %LOCALAPPDATA%\SACCM\startup.log
class StartupLog {
  static File? _file;

  static Future<void> init() async {
    try {
      final base = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['TEMP'] ??
          Directory.current.path;
      final dir = Directory('$base${Platform.pathSeparator}SACCM');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _file = File('${dir.path}${Platform.pathSeparator}startup.log');
      await _file!.writeAsString(
        '--- SACCM startup ${DateTime.now().toIso8601String()} ---\n',
        mode: FileMode.append,
      );
    } catch (_) {
      _file = null;
    }
  }

  static void step(String message) {
    try {
      _file?.writeAsStringSync(
        '[${DateTime.now().toIso8601String()}] $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  static String? get logFilePath => _file?.path;
}
