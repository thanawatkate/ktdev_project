import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

class UserSaveReadinessHint extends StatelessWidget {
  const UserSaveReadinessHint({
    super.key,
    required this.isReadyToSave,
  });

  static const String _fontFamily = 'Kanit';

  final bool isReadyToSave;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: isReadyToSave ? c.iconBgIncome : c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(
          color: isReadyToSave
              ? c.incomeGreen.withValues(alpha: 0.6)
              : c.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isReadyToSave
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: isReadyToSave ? c.incomeGreen : c.textSecondary,
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              isReadyToSave
                  ? TransactionUiText.userReadyToSave
                  : TransactionUiText.userRequiredBeforeSaveHint,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 13,
                height: 1.35,
                color: isReadyToSave ? c.incomeGreen : c.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
