import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/widgets/button/app_button.dart';

class TransactionFormHeader extends StatelessWidget {
  const TransactionFormHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.quickHint,
    required this.hintAccentColor,
    required this.hintBorderColor,
    required this.textPrimaryColor,
    this.showQuickHint = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String quickHint;
  final Color hintAccentColor;
  final Color hintBorderColor;
  final Color textPrimaryColor;
  final bool showQuickHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(AppTheme.r12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppTheme.sp12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: textPrimaryColor.withValues(alpha: 0.7),
                      fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        if (showQuickHint) ...[
          const SizedBox(height: AppTheme.sp12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.sp12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(AppTheme.r12),
              border: Border.all(color: hintBorderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: hintAccentColor),
                const SizedBox(width: AppTheme.sp8),
                Expanded(
                  child: Text(
                    quickHint,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class TransactionSummaryActions extends StatelessWidget {
  const TransactionSummaryActions({
    super.key,
    required this.totalAmount,
    required this.totalLabel,
    required this.amountColor,
    required this.cardColor,
    required this.borderColor,
    required this.textSecondaryColor,
    required this.currencyLabel,
    required this.saveLabel,
    required this.isSaving,
    required this.onSave,
    this.isSaveEnabled = true,
    this.saveDisabledHint,
    required this.isEditMode,
    required this.cancelLabel,
    this.onCancel,
    this.showSaveButton = true,
  });

  final double totalAmount;
  final String totalLabel;
  final Color amountColor;
  final Color cardColor;
  final Color borderColor;
  final Color textSecondaryColor;
  final String currencyLabel;
  final String saveLabel;
  final bool isSaving;
  final VoidCallback onSave;
  final bool isSaveEnabled;
  final String? saveDisabledHint;
  final bool isEditMode;
  final String cancelLabel;
  final VoidCallback? onCancel;
  final bool showSaveButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalLabel,
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat('#,##0.00').format(totalAmount)} $currencyLabel',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showSaveButton) ...[
            const SizedBox(height: AppTheme.sp12),
            Row(
              children: [
                if (isEditMode) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sp12),
                ],
                Expanded(
                  child: AppButton.primary(
                    label: saveLabel,
                    isLoading: isSaving,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    onPressed: isSaveEnabled ? onSave : null,
                  ),
                ),
              ],
            ),
            if (!isSaveEnabled && (saveDisabledHint?.isNotEmpty ?? false)) ...[
              const SizedBox(height: AppTheme.sp8),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: textSecondaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      saveDisabledHint!,
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ], // end showSaveButton
        ],
      ),
    );
  }
}
