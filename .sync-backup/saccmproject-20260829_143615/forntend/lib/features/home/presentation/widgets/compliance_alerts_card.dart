import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/home/domain/entities/compliance_alert.dart';

class ComplianceAlertsCard extends StatelessWidget {
  const ComplianceAlertsCard({
    super.key,
    required this.alerts,
    required this.todayClosed,
    this.onOpenDailyClosing,
  });

  final List<ComplianceAlert> alerts;
  final bool todayClosed;
  final VoidCallback? onOpenDailyClosing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (alerts.isEmpty && todayClosed) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  color: c.expenseRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  TransactionUiText.complianceAlertsTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
              if (!todayClosed && onOpenDailyClosing != null)
                TextButton(
                  onPressed: onOpenDailyClosing,
                  child: Text(
                    TransactionUiText.dailyClosingAction,
                    style: TextStyle(fontSize: 12, color: c.navy),
                  ),
                ),
            ],
          ),
          if (todayClosed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '✓ ${TransactionUiText.dailyClosingAlreadyClosed}',
                style: TextStyle(color: c.incomeGreen, fontSize: 12),
              ),
            ),
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                TransactionUiText.complianceAlertsEmpty,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            )
          else
            ...alerts.take(6).map((a) => _alertTile(context, a, c)),
        ],
      ),
    );
  }

  Widget _alertTile(BuildContext context, ComplianceAlert a, AppColors c) {
    Color accent;
    String badge;
    if (a.isCritical) {
      accent = c.expenseRed;
      badge = TransactionUiText.complianceSeverityCritical;
    } else if (a.isWarning) {
      accent = c.loanAmber;
      badge = TransactionUiText.complianceSeverityWarning;
    } else {
      accent = c.navy;
      badge = TransactionUiText.complianceSeverityInfo;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(fontSize: 10, color: accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  a.message,
                  style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
