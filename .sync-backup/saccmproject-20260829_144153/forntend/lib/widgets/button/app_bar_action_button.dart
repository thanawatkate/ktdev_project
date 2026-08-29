import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';

class AppBarActionButton extends StatelessWidget {
  const AppBarActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.isPrimary = false,
    this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final bool isPrimary;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final resolvedOnPressed = isEnabled && !isLoading ? onPressed : null;
    final actionColor = scheme.primary;
    final disabledActionColor = colors.textSecondary;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ) ??
        const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        );

    if (isPrimary) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: AppTheme.sp8),
        child: FilledButton(
          onPressed: resolvedOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(72, 36),
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: AppTheme.sp16),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99),
            ),
            textStyle: textStyle,
          ),
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimary,
                  ),
                )
              : Text(label),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppTheme.sp4),
      child: TextButton(
        onPressed: resolvedOnPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(56, 36),
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: AppTheme.sp12),
          foregroundColor: isEnabled ? actionColor : disabledActionColor,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textStyle,
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: actionColor,
                ),
              )
            : Text(
                label,
                style: textStyle.copyWith(
                  color: isEnabled ? actionColor : disabledActionColor,
                ),
              ),
      ),
    );
  }
}
