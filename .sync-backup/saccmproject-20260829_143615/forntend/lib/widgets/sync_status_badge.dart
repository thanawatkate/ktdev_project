import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';

class SyncUiRules {
  const SyncUiRules._();

  /// แสดง UI ที่สื่อถึงการส่งข้อมูลขึ้น server เฉพาะเครื่องที่ activate
  /// แพ็กเกจออนไลน์+ออฟไลน์แล้ว ไม่ผูกกับการมี server JWT ใน session ปัจจุบัน
  static bool canShowServerSyncUi(BuildContext context) {
    return context.select<SimpleAuthProvider, bool>(
      (auth) => auth.canShowServerSyncUi,
    );
  }
}

class ServerSyncStatusBadge extends StatelessWidget {
  const ServerSyncStatusBadge({
    super.key,
    required this.synced,
    this.syncedColor,
    this.pendingColor,
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.fontSize = 10,
    this.fontFamily = 'Kanit',
    this.showBorder = true,
  });

  final bool synced;
  final Color? syncedColor;
  final Color? pendingColor;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double fontSize;
  final String? fontFamily;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    if (!SyncUiRules.canShowServerSyncUi(context)) {
      return const SizedBox.shrink();
    }

    final color = synced
        ? (syncedColor ?? Colors.green)
        : (pendingColor ?? Colors.orange);
    final label =
        synced ? TransactionUiText.synced : TransactionUiText.pendingSync;

    return Padding(
      padding: margin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(borderRadius),
          border: showBorder
              ? Border.all(color: color.withValues(alpha: 0.35))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: fontFamily,
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
