import 'package:flutter/foundation.dart';

/// แจ้ง [HomePage] ให้โหลด snapshot เมนูใหม่หลังแก้ [app_menu]
class MenuRefreshBus {
  MenuRefreshBus._();

  static VoidCallback? _listener;

  static void register(VoidCallback listener) {
    _listener = listener;
  }

  static void unregister(VoidCallback listener) {
    if (_listener == listener) _listener = null;
  }

  static void notify() => _listener?.call();
}
