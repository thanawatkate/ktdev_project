import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

import '../view_models/budget_dashboard_view_models.dart';

/// การ์ดแหล่งเงิน + แถบความคืบหน้า (ใช้แล้ว / กันไว้ / คงเหลือ)
class BudgetDashboardSourceCard extends StatelessWidget {
  const BudgetDashboardSourceCard({
    super.key,
    required this.row,
    required this.usedColor,
    required this.reservedColor,
    required this.availableColor,
  });

  final BudgetDashboardSourceRow row;
  final Color usedColor;
  final Color reservedColor;
  final Color availableColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fmt = NumberFormat('#,##0.00');
    final cap = row.totalCap;
    final used = row.usedAmount;
    final reserved = row.reservedAmount;
    final available = row.available;
    final over = available < 0;

    // สัดส่วนแถบ: เทียบกับวงเงินรวม (ยกมา + ปีนี้); ถ้าเกินวงเงินให้แบ่งแดง/ส้มเต็มแถบ
    double flexUsed;
    double flexReserved;
    double flexAvail;
    if (cap <= 0) {
      flexUsed = flexReserved = flexAvail = 0;
    } else if (used + reserved <= cap) {
      flexUsed = used;
      flexReserved = reserved;
      flexAvail = available.clamp(0.0, cap);
    } else {
      final spent = used + reserved;
      flexAvail = 0;
      flexUsed = spent > 0 ? cap * (used / spent) : 0;
      flexReserved = spent > 0 ? cap * (reserved / spent) : 0;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.code,
                        style: TextStyle(
                          color: c.textHint,
                          fontSize: 12,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      if (row.budgetTypeLabel != null &&
                          row.budgetTypeLabel!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Text(
                                row.budgetTypeLabel!,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (over)
                  Padding(
                    padding: const EdgeInsets.only(left: AppTheme.sp8),
                    child: Chip(
                      label: Text(
                        TransactionUiText.overBudget,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Kanit',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.sp12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (flexUsed > 0)
                      Expanded(
                        flex: (flexUsed * 1000).round().clamp(1, 1000000),
                        child: ColoredBox(color: usedColor),
                      ),
                    if (flexReserved > 0)
                      Expanded(
                        flex: (flexReserved * 1000).round().clamp(1, 1000000),
                        child: ColoredBox(color: reservedColor),
                      ),
                    if (flexAvail > 0)
                      Expanded(
                        flex: (flexAvail * 1000).round().clamp(1, 1000000),
                        child: ColoredBox(color: availableColor),
                      ),
                    if (flexUsed + flexReserved + flexAvail <= 0)
                      Expanded(child: ColoredBox(color: c.dividerColor)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.sp12),
            Wrap(
              spacing: AppTheme.sp12,
              runSpacing: AppTheme.sp8,
              children: [
                _LegendDot(
                  color: usedColor,
                  label: TransactionUiText.budgetDashboardLegendUsed,
                  value: '฿${fmt.format(used)}',
                  c: c,
                ),
                _LegendDot(
                  color: reservedColor,
                  label: TransactionUiText.budgetDashboardLegendReserved,
                  value: '฿${fmt.format(reserved)}',
                  c: c,
                ),
                _LegendDot(
                  color: availableColor,
                  label: TransactionUiText.budgetDashboardLegendAvailable,
                  value: '฿${fmt.format(available)}',
                  c: c,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp8),
            Text(
              '${TransactionUiText.totalBudgetEnvelope}: ฿${fmt.format(cap)} · '
              '${(cap > 0 ? (row.committed / cap * 100) : 0).toStringAsFixed(1)}% '
              '${TransactionUiText.budgetDashboardOfCapSuffix}',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontFamily: 'Kanit',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
    required this.c,
  });

  final Color color;
  final String label;
  final String value;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontFamily: 'Kanit',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }
}
