/// No-op startup log on platforms without dart:io (e.g. web).
class StartupLog {
  static Future<void> init() async {}

  static void step(String message) {}

  static String? get logFilePath => null;
}
