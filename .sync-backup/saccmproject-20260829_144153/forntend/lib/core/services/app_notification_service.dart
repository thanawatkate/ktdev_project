import 'dart:async';

import 'package:flutter/foundation.dart';

enum AppNotificationLevel {
  info,
  success,
  warning,
  error,
}

class AppNotificationMessage {
  const AppNotificationMessage({
    required this.title,
    required this.message,
    required this.level,
    this.busy = false,
  });

  final String title;
  final String message;
  final AppNotificationLevel level;
  final bool busy;
}

/// Non-blocking app notification shown from app bars instead of modal popups.
class AppNotificationService extends ChangeNotifier {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  Timer? _clearTimer;
  AppNotificationMessage? _current;

  AppNotificationMessage? get current => _current;

  void show({
    required String title,
    required String message,
    AppNotificationLevel level = AppNotificationLevel.info,
    Duration duration = const Duration(seconds: 4),
    bool busy = false,
  }) {
    _clearTimer?.cancel();
    _current = AppNotificationMessage(
      title: title,
      message: _compactMessage(message),
      level: level,
      busy: busy,
    );
    notifyListeners();

    if (!busy) {
      _clearTimer = Timer(duration, clear);
    }
  }

  void showInfo(String title, String message, {Duration? duration}) {
    show(
      title: title,
      message: message,
      level: AppNotificationLevel.info,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  void showSuccess(String title, String message, {Duration? duration}) {
    show(
      title: title,
      message: message,
      level: AppNotificationLevel.success,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  void showWarning(String title, String message, {Duration? duration}) {
    show(
      title: title,
      message: message,
      level: AppNotificationLevel.warning,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  void showError(String title, String message, {Duration? duration}) {
    show(
      title: title,
      message: message,
      level: AppNotificationLevel.error,
      duration: duration ?? const Duration(seconds: 6),
    );
  }

  void showBusy(String title, String message) {
    show(
      title: title,
      message: message,
      level: AppNotificationLevel.info,
      busy: true,
    );
  }

  void clear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  String _compactMessage(String raw) {
    final lowerRaw = raw.toLowerCase();
    final looksLikeHtml = lowerRaw.contains('<html') ||
        lowerRaw.contains('<!doctype') ||
        lowerRaw.contains('<body') ||
        lowerRaw.contains('</');
    if (looksLikeHtml) {
      return 'ระบบไม่สามารถให้บริการได้ชั่วคราว กรุณาลองใหม่อีกครั้งในภายหลัง';
    }

    var text = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    if (text.length > 180) return '${text.substring(0, 180)}...';
    return text;
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }
}
