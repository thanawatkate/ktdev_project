import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

class ExpenseTypeListEmptyState extends StatelessWidget {
  final bool isTotallyEmpty;
  final bool hasActiveFilter;
  final VoidCallback onClearFilters;

  const ExpenseTypeListEmptyState({
    super.key,
    required this.isTotallyEmpty,
    required this.hasActiveFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isTotallyEmpty
                ? TransactionUiText.expenseTypeListEmpty
                : TransactionUiText.notFound,
            style: TextStyle(color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          if (hasActiveFilter)
            TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text(TransactionUiText.clearFilters),
            ),
        ],
      ),
    );
  }
}
