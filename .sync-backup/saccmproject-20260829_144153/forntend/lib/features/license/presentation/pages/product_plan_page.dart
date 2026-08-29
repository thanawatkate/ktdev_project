import 'package:flutter/material.dart';
import 'package:saccm/config.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/license/presentation/pages/license_activation_page.dart';
import 'package:saccm/features/license/presentation/pages/license_info_page.dart';
import 'package:saccm/features/license/presentation/widgets/product_tier_card.dart';
import 'package:saccm/features/license/product_tier.dart';
import 'package:saccm/widgets/widgets.dart';

/// แผนการขาย 3 แพ็กเกจ + สถานะปัจจุบัน
class ProductPlanPage extends StatefulWidget {
  const ProductPlanPage({super.key});

  @override
  State<ProductPlanPage> createState() => _ProductPlanPageState();
}

class _ProductPlanPageState extends State<ProductPlanPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  LicenseSnapshot? _snap;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snap = await LicenseMode.snapshot();
    if (!mounted) return;
    setState(() {
      _snap = snap;
      _loading = false;
    });
  }

  String _formatDate(DateTime d) {
    return ThaiDateFormatter.format(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final snap = _snap;

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildAppBar(c),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: scheme.primary))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 900
                      ? AppTheme.sp24
                      : AppTheme.sp16;

                  return RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        AppTheme.sp16,
                        horizontalPadding,
                        AppTheme.sp16,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _maxResponsiveFormWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TransactionFormHeader(
                                icon: Icons.workspace_premium_outlined,
                                iconColor: scheme.primary,
                                iconBgColor: c.iconBgIncome,
                                title: TransactionUiText.productPlanTitle,
                                subtitle: TransactionUiText.productPlanLead,
                                quickHint: TransactionUiText.productPlanLead,
                                hintAccentColor: scheme.primary,
                                hintBorderColor: c.cardBorder,
                                textPrimaryColor: c.textPrimary,
                              ),
                              const SizedBox(height: AppTheme.sp16),
                              if (snap != null) ...[
                                _CurrentStatusBanner(
                                  snap: snap,
                                  formatDate: _formatDate,
                                ),
                                const SizedBox(height: AppTheme.sp16),
                              ],
                              _SectionHeader(
                                title:
                                    TransactionUiText.productPlanOptionsTitle,
                                subtitle: TransactionUiText
                                    .productPlanOptionsSubtitle,
                                colors: c,
                              ),
                              const SizedBox(height: AppTheme.sp8),
                              _buildTierLayout(context, snap),
                              const SizedBox(height: AppTheme.sp24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: c.cardWhite,
      title: Text(
        TransactionUiText.productPlanTitle,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: TransactionUiText.retry,
          onPressed: _loading ? null : _load,
          icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  void _openActivate(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const LicenseActivationPage()),
        )
        .then((_) => _load());
  }

  Widget _buildTierLayout(BuildContext context, LicenseSnapshot? snap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppTheme.sp12;
        final columnCount = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columnCount - 1))) /
                columnCount;

        final cards = [
          ProductTierCard(
            tier: ProductTier.trial,
            title: TransactionUiText.productTierTrialTitle,
            subtitle: TransactionUiText.productTierTrialSubtitle(
              kEmbeddedTrialDays,
            ),
            icon: Icons.schedule_rounded,
            isCurrent: snap?.tier == ProductTier.trial,
            currentBadgeLabel: TransactionUiText.productTierTrialCurrentBadge,
            features: TransactionUiText.productTierTrialFeatures(
              kEmbeddedTrialDays,
            ),
          ),
          ProductTierCard(
            tier: ProductTier.offline,
            title: TransactionUiText.productTierOfflineTitle,
            subtitle: TransactionUiText.productTierOfflineSubtitle,
            icon: Icons.storage_rounded,
            isCurrent: snap?.tier == ProductTier.offline,
            currentBadgeLabel: TransactionUiText.productTierCurrentBadge,
            features: TransactionUiText.productTierOfflineFeatures,
            actionLabel: snap?.tier == ProductTier.offline
                ? TransactionUiText.licenseInfoTitle
                : TransactionUiText.productTierActivateLicense,
            onAction: snap?.tier == ProductTier.offline
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LicenseInfoPage(),
                      ),
                    )
                : () => _openActivate(context),
          ),
          ProductTierCard(
            tier: ProductTier.online,
            title: TransactionUiText.productTierOnlineTitle,
            subtitle: TransactionUiText.productTierOnlineSubtitle,
            icon: Icons.cloud_sync_rounded,
            isCurrent: snap?.tier == ProductTier.online,
            currentBadgeLabel: TransactionUiText.productTierCurrentBadge,
            isRecommended: snap?.tier == ProductTier.trial,
            features: TransactionUiText.productTierOnlineFeatures,
            actionLabel: snap?.tier == ProductTier.online
                ? TransactionUiText.licenseInfoTitle
                : TransactionUiText.productTierActivateLicense,
            onAction: snap?.tier == ProductTier.online
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LicenseInfoPage(),
                      ),
                    )
                : () => _openActivate(context),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _CurrentStatusBanner extends StatelessWidget {
  const _CurrentStatusBanner({
    required this.snap,
    required this.formatDate,
  });

  final LicenseSnapshot snap;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    String title;
    String detail;
    IconData icon;
    Color accentColor;
    Color iconBgColor;

    switch (snap.tier) {
      case ProductTier.trial:
        final t = snap.trial!;
        title = TransactionUiText.productTierTrialTitle;
        icon = Icons.schedule_rounded;
        accentColor = c.loanAmber;
        iconBgColor = c.iconBgLoan;
        detail = t.expired
            ? TransactionUiText.embeddedTrialExpiredTitle
            : TransactionUiText.embeddedTrialLoginBanner(
                t.daysRemaining,
                t.daysTotal,
              );
        break;
      case ProductTier.offline:
        title = TransactionUiText.productTierOfflineTitle;
        icon = Icons.storage_rounded;
        accentColor = scheme.primary;
        iconBgColor = c.iconBgIncome;
        detail = snap.schoolName ?? TransactionUiText.licenseLoginSchoolBanner;
        if (snap.licenseExpiresAt != null) {
          detail +=
              ' · ${TransactionUiText.licenseExpiresLabel} ${formatDate(snap.licenseExpiresAt!)}';
        }
        break;
      case ProductTier.online:
        title = TransactionUiText.productTierOnlineTitle;
        icon = Icons.cloud_sync_rounded;
        accentColor = c.incomeGreen;
        iconBgColor = c.iconBgIncome;
        detail = snap.schoolName ?? TransactionUiText.licenseLoginSchoolBanner;
        if (snap.licenseExpiresAt != null) {
          detail +=
              ' · ${TransactionUiText.licenseExpiresLabel} ${formatDate(snap.licenseExpiresAt!)}';
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: accentColor.withValues(alpha: 0.42)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final badge = _StatusBadge(
            label: TransactionUiText.productTierCurrentBadge,
            color: accentColor,
          );

          return Row(
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
                      '${TransactionUiText.productPlanCurrentStatusBadge}: $title',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 13,
                        color: c.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    if (constraints.maxWidth < 560) ...[
                      const SizedBox(height: AppTheme.sp8),
                      badge,
                    ],
                  ],
                ),
              ),
              if (constraints.maxWidth >= 560) ...[
                const SizedBox(width: AppTheme.sp12),
                badge,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontFamily: 'Kanit',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp8,
        vertical: AppTheme.sp4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.r8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Kanit',
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
