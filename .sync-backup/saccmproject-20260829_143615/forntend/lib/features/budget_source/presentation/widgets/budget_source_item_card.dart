import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';

class BudgetSourceItemCard extends StatelessWidget {
  static const _auditFarYearTag = '[AUDIT:FAR_YEAR]';
  final BudgetSourceModel item;
  final VoidCallback onEdit;
  final VoidCallback onEditAmounts;
  final VoidCallback onDelete;

  const BudgetSourceItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onEditAmounts,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isFarYearAudit = (item.description ?? '').contains(_auditFarYearTag);
    final fmt = NumberFormat('#,##0.00');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.cardBorder),
      ),
      color: c.cardWhite,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: c.navy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(item.code,
                  style: TextStyle(color: c.navy, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(item.name,
                    style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary))),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'amounts') onEditAmounts();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text(TransactionUiText.edit)),
                const PopupMenuItem(
                  value: 'amounts',
                  child: Text(TransactionUiText.menuBudgetAmounts),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(TransactionUiText.delete, style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${TransactionUiText.fiscalYearPrefix}${item.fiscalYear}',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ),
              if (item.moneyGroupName != null && item.moneyGroupName!.isNotEmpty)
                _chip(item.moneyGroupName!, c),
              if (item.bankAccountName != null && item.bankAccountName!.isNotEmpty)
                _chip(
                  '🏦 ${item.bankAccountName!}',
                  c,
                  color: c.navy.withValues(alpha: 0.08),
                  textColor: c.navy,
                ),
              if (isFarYearAudit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ปีไกล',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _moneyRow(c, TransactionUiText.broughtForwardBudget,
              fmt.format(item.broughtForwardAmount)),
          _moneyRow(c, TransactionUiText.budgetAmountBaht, fmt.format(item.budgetAmount)),
          _moneyRow(
            c,
            TransactionUiText.totalBudgetEnvelope,
            fmt.format(item.totalAllocated),
            strong: true,
          ),
          _moneyRow(c, TransactionUiText.used, fmt.format(item.usedAmount)),
          _moneyRow(
            c,
            TransactionUiText.budgetDashboardLegendReserved,
            fmt.format(item.reservedAmount),
            valueColor: item.reservedAmount > 0 ? c.loanAmber : c.textSecondary,
          ),
          _moneyRow(c, TransactionUiText.remaining, fmt.format(item.remaining),
              valueColor: item.remaining >= 0 ? c.incomeGreen : Colors.red),
        ]),
      ),
    );
  }

  Widget _moneyRow(AppColors c, String label, String value,
      {bool strong = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '$value ${TransactionUiText.baht}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, AppColors c, {Color? color, Color? textColor}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color ?? c.surface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: textColor ?? c.textSecondary),
        ),
      );
}
