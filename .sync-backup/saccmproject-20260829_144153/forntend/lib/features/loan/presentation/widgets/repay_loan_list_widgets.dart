import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

class RepayLoanSummaryCard extends StatelessWidget {
  const RepayLoanSummaryCard({super.key, required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder),
      ),
      child: Text(
        '${TransactionUiText.repayLoanSummaryPrefix} ${NumberFormat('#,##0.00').format(total)} ${TransactionUiText.baht}',
        style: TextStyle(
          color: c.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RepayLoanSearchBar extends StatelessWidget {
  const RepayLoanSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppInput(
        controller: controller,
        onChanged: onChanged,
        hint: TransactionUiText.repayLoanSearchHint,
        prefixIcon: const Icon(Icons.search_rounded),
        action: AppInputAction.text(
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}

class RepayLoanListItemCard extends StatelessWidget {
  const RepayLoanListItemCard({
    super.key,
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
    final refLoan = row['refLoan']?.toString() ?? '-';
    return ListTile(
      tileColor: c.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.cardBorder),
      ),
      title: Text(
        refLoan,
        style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary),
      ),
      subtitle: Text(
        row['remark']?.toString().isNotEmpty == true
            ? row['remark'].toString()
            : '-',
        style: TextStyle(color: c.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            NumberFormat('#,##0.00').format(amount),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: c.expenseRed),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class RepayLoanEmptyState extends StatelessWidget {
  const RepayLoanEmptyState({super.key, required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        hasSearch ? TransactionUiText.notFound : TransactionUiText.repayLoanEmpty,
        style: TextStyle(color: AppColors.of(context).textSecondary),
      ),
    );
  }
}
