import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

class UserErrorView extends StatelessWidget {
  const UserErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  static const String _fontFamily = 'Kanit';

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.sp12),
            Text(
              TransactionUiText.genericError,
              style: TextStyle(
                color: c.textPrimary,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppTheme.sp8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontFamily: _fontFamily,
              ),
            ),
            const SizedBox(height: AppTheme.sp16),
            AppButton.outlined(
              label: TransactionUiText.retry,
              fullWidth: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
