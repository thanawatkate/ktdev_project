import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

import '../view_models/budget_dashboard_view_models.dart';

/// การ์ดสรุปยอดรวม (Total Overview) ปีงบประมาณปัจจุบัน
class BudgetDashboardOverviewCard extends StatelessWidget {
  const BudgetDashboardOverviewCard({
    super.key,
    required this.totals,
    required this.usedColor,
    required this.reservedColor,
    required this.availableColor,
  });

  final BudgetDashboardTotals totals;
  final Color usedColor;
  final Color reservedColor;
  final Color availableColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');

    Widget rowAmount(String label, double amount, Color accent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sp8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTheme.sp12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Kanit',
                ),
              ),
            ),
            Text(
              '฿${fmt.format(amount)}',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Kanit',
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
      color: c.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.r16),
        side: BorderSide(color: c.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: scheme.primary, size: 22),
                const SizedBox(width: AppTheme.sp8),
                Expanded(
                  child: Text(
                    TransactionUiText.budgetDashboardOverviewTitle,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp4),
            Text(
              TransactionUiText.budgetDashboardFiscalYearLine(totals.fiscalYear),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Kanit',
              ),
            ),
            const Divider(height: AppTheme.sp24),
            rowAmount(TransactionUiText.budgetDashboardTotalBudget, totals.totalBudget, scheme.outline),
            rowAmount(TransactionUiText.budgetDashboardTotalUsed, totals.totalUsed, usedColor),
            rowAmount(TransactionUiText.budgetDashboardTotalReserved, totals.totalReserved, reservedColor),
            const Divider(height: AppTheme.sp24),
            rowAmount(TransactionUiText.budgetDashboardAvailable, totals.available, availableColor),
          ],
        ),
      ),
    );
  }
}
