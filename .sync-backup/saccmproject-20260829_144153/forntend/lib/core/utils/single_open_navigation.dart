import 'package:flutter/material.dart';

class SingleOpenNavigation {
  SingleOpenNavigation._();

  static final Set<String> _activeKeys = <String>{};

  static String _navigatorScopedKey(
    BuildContext context,
    String key, {
    bool useRootNavigator = false,
  }) {
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    return '${identityHashCode(navigator)}:$key';
  }

  static String _navigatorKeyPrefix(NavigatorState navigator) =>
      '${identityHashCode(navigator)}:';

  static bool hasActiveForNavigator(NavigatorState navigator) {
    final prefix = _navigatorKeyPrefix(navigator);
    return _activeKeys.any((key) => key.startsWith(prefix));
  }

  static void clearForNavigator(NavigatorState navigator) {
    final prefix = _navigatorKeyPrefix(navigator);
    _activeKeys.removeWhere((key) => key.startsWith(prefix));
  }

  static Future<T?> run<T>(
    String key,
    Future<T?> Function() action,
  ) async {
    if (!_activeKeys.add(key)) return null;
    try {
      return await action();
    } finally {
      _activeKeys.remove(key);
    }
  }

  static Future<void> runVoid(
    String key,
    Future<void> Function() action,
  ) async {
    if (!_activeKeys.add(key)) return;
    try {
      await action();
    } finally {
      _activeKeys.remove(key);
    }
  }

  static Future<T?> runForNavigator<T>(
    BuildContext context, {
    required String key,
    required Future<T?> Function() action,
    bool useRootNavigator = false,
  }) {
    return run<T>(
      _navigatorScopedKey(
        context,
        key,
        useRootNavigator: useRootNavigator,
      ),
      action,
    );
  }

  static Future<T?> push<T>(
    BuildContext context, {
    required String key,
    required Route<T> route,
  }) {
    return run<T>(
      _navigatorScopedKey(context, key),
      () => Navigator.of(context).push<T>(route),
    );
  }

  static Future<T?> showSheet<T>(
    BuildContext context, {
    required String key,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool useSafeArea = false,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    ShapeBorder? shape,
    bool? showDragHandle,
    RouteSettings? routeSettings,
  }) {
    return run<T>(
      _navigatorScopedKey(
        context,
        key,
        useRootNavigator: useRootNavigator,
      ),
      () => showModalBottomSheet<T>(
        context: context,
        builder: builder,
        isScrollControlled: isScrollControlled,
        useSafeArea: useSafeArea,
        useRootNavigator: useRootNavigator,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        backgroundColor: backgroundColor,
        shape: shape,
        showDragHandle: showDragHandle,
        routeSettings: routeSettings,
      ),
    );
  }
}
