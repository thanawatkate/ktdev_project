import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

class LoanFormPairOrStack extends StatelessWidget {
  const LoanFormPairOrStack({
    super.key,
    required this.wide,
    required this.left,
    required this.right,
    this.gap = AppTheme.sp12,
  });

  final bool wide;
  final Widget left;
  final Widget right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          SizedBox(height: gap),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: gap),
        Expanded(child: right),
      ],
    );
  }
}

class LoanFormSectionHeader extends StatelessWidget {
  const LoanFormSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.fontFamily = 'Kanit',
    this.titleFontSize = 13,
    this.titleLetterSpacing = 0.3,
    this.contentPadding = const EdgeInsets.fromLTRB(
      AppTheme.sp16,
      AppTheme.sp16,
      AppTheme.sp16,
      AppTheme.sp12,
    ),
    this.subtitleLeftInset = 26,
    this.subtitleMonospace = false,
    this.subtitleFontSize = 11,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String fontFamily;
  final double titleFontSize;
  final double titleLetterSpacing;
  final EdgeInsets contentPadding;
  final double subtitleLeftInset;
  final bool subtitleMonospace;
  final double subtitleFontSize;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: AppTheme.sp8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: c.textPrimary,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: titleLetterSpacing,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: subtitleLeftInset),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontFamily:
                      subtitleMonospace ? 'Consolas, monospace' : fontFamily,
                  fontSize: subtitleFontSize,
                  height: 1.35,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
