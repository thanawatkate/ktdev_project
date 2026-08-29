import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

class LoanListHeader extends StatelessWidget {
  const LoanListHeader({
    super.key,
    required this.total,
    required this.count,
  });

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      color: c.cardWhite,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TransactionUiText.summaryLoan,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LoanSummaryCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: TransactionUiText.summaryTotal,
                  value: NumberFormat('#,##0.00').format(total),
                  unit: TransactionUiText.baht,
                  valueColor: c.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LoanSummaryCard(
                  icon: Icons.receipt_outlined,
                  label: TransactionUiText.itemCount,
                  value: '$count',
                  unit: TransactionUiText.items,
                  valueColor: c.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LoanListSearchBar extends StatelessWidget {
  const LoanListSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.of(context).cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AppInput(
        controller: controller,
        focusNode: focusNode,
        hint: TransactionUiText.loanSearchHint,
        onChanged: onChanged,
        prefixIcon: const Icon(Icons.search),
        action: AppInputAction.text(
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}

class LoanListItemCard extends StatelessWidget {
  const LoanListItemCard({
    super.key,
    required this.row,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
    final opening =
        double.tryParse(row['opening_outstanding']?.toString() ?? '0') ?? 0;
    final totalPrincipal = amount + opening;
    final borrower = row['borrower']?.toString() ?? '-';
    final remark = row['remark']?.toString() ?? '';
    final created = row['created']?.toString() ?? '';
    final synced = row['synced'] == true;
    final outstanding = (row['outstanding'] as num?)?.toDouble() ??
        double.tryParse(row['outstanding']?.toString() ?? '0') ??
        0;
    final isOverdue = row['is_overdue'] == true;
    final dueDateRaw = row['duedate']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.iconBgIncome,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: c.navy,
            size: 18,
          ),
        ),
        title: Text(
          borrower,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: c.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (remark.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${TransactionUiText.notePrefix}$remark',
                  style: TextStyle(color: c.textHint, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDate(created),
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
                if (dueDateRaw.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${TransactionUiText.loanDueDate} ${_formatDate(dueDateRaw)}',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                ],
                ServerSyncStatusBadge(
                  synced: synced,
                  borderRadius: 10,
                  margin: const EdgeInsets.only(left: 8),
                ),
                if (outstanding > 0) ...[
                  const SizedBox(width: 6),
                  _LoanStatusBadge(
                    text: isOverdue
                        ? TransactionUiText.loanOverdueBadge
                        : TransactionUiText.loanOutstandingBadge,
                    color: isOverdue ? c.expenseRed : c.loanAmber,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 82,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat('#,##0.00').format(totalPrincipal),
                      style: TextStyle(
                        color: c.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (opening > 0)
                      Text(
                        TransactionUiText.loanAmountDocPlusBrought(
                          NumberFormat('#,##0.00').format(amount),
                          NumberFormat('#,##0.00').format(opening),
                        ),
                        style: TextStyle(color: c.textHint, fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      TransactionUiText.baht,
                      style: TextStyle(color: c.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: TransactionUiText.edit,
                icon: Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: TransactionUiText.delete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: c.expenseRed,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    return ThaiDateFormatter.format(raw, fallback: raw);
  }
}

class LoanListEmptyState extends StatelessWidget {
  const LoanListEmptyState({super.key, required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch
                ? Icons.search_off
                : Icons.account_balance_wallet_outlined,
            size: 64,
            color: c.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? TransactionUiText.notFound
                : TransactionUiText.emptyLoan,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? TransactionUiText.tryAnotherKeyword
                : TransactionUiText.startByAdding,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LoanSummaryCard extends StatelessWidget {
  const _LoanSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: valueColor, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '  $unit',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoanStatusBadge extends StatelessWidget {
  const _LoanStatusBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
