import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

/// สถานะว่างของแต่ละแท็บหน้าอนุมัติ
class ApprovalEmptyState extends StatelessWidget {
  const ApprovalEmptyState({
    super.key,
    required this.status,
  });

  /// `pending` | `approved` | `rejected`
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    late final IconData icon;
    late final String title;
    late final String hint;
    if (status == 'pending') {
      icon = Icons.inbox_outlined;
      title = TransactionUiText.approvalEmptyPendingTitle;
      hint = TransactionUiText.approvalEmptyPendingHint;
    } else if (status == 'approved') {
      icon = Icons.task_alt_outlined;
      title = TransactionUiText.approvalEmptyApprovedTitle;
      hint = TransactionUiText.approvalEmptyApprovedHint;
    } else {
      icon = Icons.highlight_off_outlined;
      title = TransactionUiText.approvalEmptyRejectedTitle;
      hint = TransactionUiText.approvalEmptyRejectedHint;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: scheme.primary.withValues(alpha: 0.42)),
          const SizedBox(height: AppTheme.sp16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: c.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppTheme.sp8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 13,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
