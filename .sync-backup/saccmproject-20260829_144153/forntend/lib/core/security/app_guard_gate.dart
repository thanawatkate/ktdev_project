import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/security/app_guard.dart';
import 'package:saccm/widgets/widgets.dart';

/// Gate ของระบบกันแกะโค๊ด — ครอบทั้งแอป
///
/// - ถ้า [initialVerdict] ไม่ผ่าน → แสดงหน้าบล็อกแทนทั้งแอป
/// - ระหว่างรันจะตรวจ debugger ซ้ำเป็นระยะ (กันการแนบ debugger ภายหลัง)
class AppGuardGate extends StatefulWidget {
  const AppGuardGate({
    super.key,
    required this.initialVerdict,
    required this.child,
  });

  final GuardVerdict initialVerdict;
  final Widget child;

  @override
  State<AppGuardGate> createState() => _AppGuardGateState();
}

class _AppGuardGateState extends State<AppGuardGate> {
  late GuardVerdict _verdict;
  Timer? _recheckTimer;

  @override
  void initState() {
    super.initState();
    _verdict = widget.initialVerdict;
    if (_verdict == GuardVerdict.ok) {
      _recheckTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _recheck(),
      );
    }
  }

  void _recheck() {
    if (!mounted) return;
    if (AppGuard.recheckDebugger()) {
      _recheckTimer?.cancel();
      setState(() => _verdict = GuardVerdict.debuggerDetected);
    }
  }

  @override
  void dispose() {
    _recheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_verdict == GuardVerdict.ok) return widget.child;
    return _GuardBlockedScreen(verdict: _verdict);
  }
}

class _GuardBlockedScreen extends StatelessWidget {
  const _GuardBlockedScreen({required this.verdict});

  final GuardVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDebugger = verdict == GuardVerdict.debuggerDetected;

    final title = isDebugger
        ? TransactionUiText.guardDebuggerTitle
        : TransactionUiText.guardTamperTitle;
    final message = isDebugger
        ? TransactionUiText.guardDebuggerMessage
        : TransactionUiText.guardTamperMessage;

    return Material(
      color: c.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDebugger
                        ? Icons.bug_report_outlined
                        : Icons.gpp_bad_outlined,
                    size: 64,
                    color: c.textSecondary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppButton.primary(
                    label: TransactionUiText.guardExitButton,
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
