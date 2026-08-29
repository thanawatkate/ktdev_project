import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

/// หน้าแจ้งเมื่อไม่มีสิทธิ์ดู Workflow อนุมัติ
class ApprovalNoAccessView extends StatelessWidget {
  const ApprovalNoAccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text(TransactionUiText.approvalWorkflow)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.sp24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: scheme.primary.withValues(alpha: 0.85)),
                const SizedBox(height: AppTheme.sp16),
                Text(
                  TransactionUiText.noPermissionData,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
