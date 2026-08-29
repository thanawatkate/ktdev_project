import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/license/product_tier.dart';
import 'package:saccm/widgets/button/app_button.dart';

class ProductTierCard extends StatelessWidget {
  const ProductTierCard({
    super.key,
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.icon,
    this.isCurrent = false,
    this.isRecommended = false,
    this.currentBadgeLabel,
    this.actionLabel,
    this.onAction,
  });

  final ProductTier tier;
  final String title;
  final String subtitle;
  final List<String> features;
  final IconData icon;
  final bool isCurrent;
  final bool isRecommended;
  final String? currentBadgeLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final accentColor = switch (tier) {
      ProductTier.trial => c.loanAmber,
      ProductTier.offline => scheme.primary,
      ProductTier.online => c.incomeGreen,
    };
    final iconBgColor = switch (tier) {
      ProductTier.trial => c.iconBgLoan,
      ProductTier.offline => c.iconBgIncome,
      ProductTier.online => c.iconBgIncome,
    };
    final borderColor = isCurrent
        ? accentColor
        : (isRecommended ? accentColor.withValues(alpha: 0.7) : c.cardBorder);

    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: AppTheme.sp12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontFamily: 'Kanit',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                      ),
                      if (isCurrent || isRecommended) ...[
                        const SizedBox(height: AppTheme.sp8),
                        Wrap(
                          spacing: AppTheme.sp8,
                          runSpacing: AppTheme.sp4,
                          children: [
                            if (isCurrent)
                              _TierBadge(
                                label: currentBadgeLabel ??
                                    TransactionUiText.productTierCurrentBadge,
                                foregroundColor: accentColor,
                                backgroundColor:
                                    accentColor.withValues(alpha: 0.12),
                              ),
                            if (isRecommended && !isCurrent)
                              _TierBadge(
                                label: TransactionUiText
                                    .productTierRecommendedBadge,
                                foregroundColor: c.incomeGreen,
                                backgroundColor:
                                    c.incomeGreen.withValues(alpha: 0.12),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                    const SizedBox(width: AppTheme.sp8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontFamily: 'Kanit',
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.sp12),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton.outlined(
                  label: actionLabel!,
                  onPressed: onAction,
                  fullWidth: false,
                  height: 44,
                  icon: Icon(Icons.arrow_forward_rounded,
                      size: 18, color: accentColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.sp8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.r8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontFamily: 'Kanit',
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
