import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:saccm/core/services/app_notification_service.dart';

enum AutoDismissAlertPosition {
  center,
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum AutoDismissAlertType {
  info,
  success,
  warning,
  error,
}

AutoDismissAlertType _inferTypeFromTitle(String title) {
  final lower = title.toLowerCase();
  if (lower.contains('success') || lower.contains('สำเร็จ')) {
    return AutoDismissAlertType.success;
  }
  if (lower.contains('warning') || lower.contains('เตือน')) {
    return AutoDismissAlertType.warning;
  }
  if (lower.contains('error') || lower.contains('ผิดพลาด')) {
    return AutoDismissAlertType.error;
  }
  return AutoDismissAlertType.info;
}

String _compactAlertContent(String raw) {
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

  if (text.toLowerCase().contains('phusion passenger') ||
      text.toLowerCase().contains('web application could not be started')) {
    return 'ระบบไม่สามารถเริ่มต้นบริการได้ในขณะนี้ กรุณาติดต่อผู้ดูแลระบบ';
  }

  if (text.isEmpty) {
    return 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ กรุณาลองใหม่อีกครั้ง';
  }
  if (text.length > 320) {
    return '${text.substring(0, 320)}...';
  }
  return text;
}

AppNotificationLevel _levelForType(AutoDismissAlertType type) {
  switch (type) {
    case AutoDismissAlertType.success:
      return AppNotificationLevel.success;
    case AutoDismissAlertType.warning:
      return AppNotificationLevel.warning;
    case AutoDismissAlertType.error:
      return AppNotificationLevel.error;
    case AutoDismissAlertType.info:
      return AppNotificationLevel.info;
  }
}

void showAutoDismissAlert(
  BuildContext context,
  String title,
  String content,
  int? duration, {
  AutoDismissAlertPosition position = AutoDismissAlertPosition.center,
  AutoDismissAlertType? type,
}) {
  final resolvedType = type ?? _inferTypeFromTitle(title);
  final compactContent = _compactAlertContent(content);

  if (kDebugMode && compactContent != content) {
    debugPrint(
        '[AutoDismissAlert] raw_error: ${content.substring(0, content.length > 1200 ? 1200 : content.length)}');
  }

  AppNotificationService.instance.show(
    title: title,
    message: compactContent,
    level: _levelForType(resolvedType),
    duration: Duration(seconds: duration ?? 3),
  );
}
