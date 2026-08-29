import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// เปิดใช้เฉพาะ Windows / macOS / Linux (ไม่ใช้ [dart:io] เพื่อให้ compile web ได้)
bool get desktopWindowChromeEnabled =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// ความกว้างแถบปุ่มย่อ / ขยาย / ปิด — สอดคล้องกับโซน reserved ทางขวา
const double kDesktopCaptionWidth = 138;

/// จัดการหน้าต่างเดสก์ท็อป + reserved ขวาให้ปุ่ม caption
Future<void> initDesktopWindowManager() async {
  if (!desktopWindowChromeEnabled) return;
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1024, 640),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

/// ห่อทั้งแอป: กันเนื้อหาไม่ทับปุ่ม caption + วางปุ่มทับขอบขวาบน
Widget desktopAppShellBuilder(BuildContext context, Widget? child) {
  if (!desktopWindowChromeEnabled || child == null) {
    return child ?? const SizedBox.shrink();
  }
  return Stack(
    fit: StackFit.expand,
    children: [
      child,
      const Positioned(
        top: 0,
        right: 0,
        width: kDesktopCaptionWidth,
        height: kToolbarHeight,
        child: _DesktopCaptionButtons(),
      ),
    ],
  );
}

class _DesktopCaptionButtons extends StatefulWidget {
  const _DesktopCaptionButtons();

  @override
  State<_DesktopCaptionButtons> createState() => _DesktopCaptionButtonsState();
}

class _DesktopCaptionButtonsState extends State<_DesktopCaptionButtons>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    if (!desktopWindowChromeEnabled) return;
    final v = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = v);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider = isDark ? const Color(0xFF3D4D66) : const Color(0xFFC9D3E2);
    final idle = isDark ? const Color(0xFFE6ECF7) : const Color(0xFF162338);
    final hoverBg = isDark ? const Color(0xFF2A3548) : const Color(0xFFE8EEF5);

    Widget btn({
      required IconData icon,
      required VoidCallback onPressed,
      bool danger = false,
    }) {
      return _CaptionIconButton(
        icon: icon,
        onPressed: onPressed,
        idleColor: idle,
        hoverBackground: danger ? const Color(0xFFE81123) : hoverBg,
        hoverForeground: danger ? Colors.white : idle,
      );
    }

    return Material(
      color: Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 1, color: divider),
          Expanded(
            child: btn(
              icon: Icons.remove_rounded,
              onPressed: () => windowManager.minimize(),
            ),
          ),
          Expanded(
            child: btn(
              icon: _maximized
                  ? Icons.fullscreen_exit_rounded
                  : Icons.crop_square_rounded,
              onPressed: () async {
                if (_maximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
                await _syncMaximized();
              },
            ),
          ),
          Expanded(
            child: btn(
              icon: Icons.close_rounded,
              onPressed: () => windowManager.close(),
              danger: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionIconButton extends StatefulWidget {
  const _CaptionIconButton({
    required this.icon,
    required this.onPressed,
    required this.idleColor,
    required this.hoverBackground,
    required this.hoverForeground,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color idleColor;
  final Color hoverBackground;
  final Color hoverForeground;

  @override
  State<_CaptionIconButton> createState() => _CaptionIconButtonState();
}

class _CaptionIconButtonState extends State<_CaptionIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: _hover ? widget.hoverBackground : Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          child: SizedBox(
            width: double.infinity,
            height: kToolbarHeight,
            child: Icon(
              widget.icon,
              size: 18,
              color: _hover ? widget.hoverForeground : widget.idleColor,
            ),
          ),
        ),
      ),
    );
  }
}
