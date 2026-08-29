import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// จัดการ ThemeMode ของแอป พร้อม persist ลง SharedPreferences
///
/// ใช้งานจาก widget: ดึง [ThemeModeProvider] ผ่าน Provider แล้วเรียก [toggle] หรือ [setMode]
///
/// อ่านค่า: watch [ThemeModeProvider] เพื่อดูโหมดปัจจุบันและสถานะมืด/สว่าง
class ThemeModeProvider extends ChangeNotifier {
  static const _prefKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  bool get isLight => _mode == ThemeMode.light;
  bool get isSystem => _mode == ThemeMode.system;

  ThemeModeProvider() {
    _loadFromPrefs();
  }

  /// สลับระหว่าง light ↔ dark (ข้ามโหมด system)
  Future<void> toggle() async {
    await setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  /// ตั้งค่า theme mode และบันทึก
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _saveToPrefs(mode);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    final loaded = switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    if (loaded == _mode) return;
    _mode = loaded;
    notifyListeners();
  }

  Future<void> _saveToPrefs(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.name);
  }
}
