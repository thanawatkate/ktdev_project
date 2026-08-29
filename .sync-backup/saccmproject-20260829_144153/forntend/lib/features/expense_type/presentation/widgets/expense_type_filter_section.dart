import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

class ExpenseTypeFilterSection extends StatelessWidget {
  final TextEditingController searchController;
  final String sortBy;
  final bool hasActiveFilter;
  final int resultCount;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onResetFilters;
  final String footnote;

  const ExpenseTypeFilterSection({
    super.key,
    required this.searchController,
    required this.sortBy,
    required this.hasActiveFilter,
    required this.resultCount,
    required this.onSortChanged,
    required this.onResetFilters,
    required this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        children: [
          AppInput(
            controller: searchController,
            hint: 'ค้นหาชื่อ/รหัส/คำอธิบาย...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: AppDropdownField<String>(
                  value: sortBy,
                  density: AppDropdownDensity.compact,
                  items: const [
                    AppDropdownItem(value: 'sort_asc', label: 'ตามลำดับที่กำหนด'),
                    AppDropdownItem(value: 'name_asc', label: 'ชื่อ (ก-ฮ)'),
                  ],
                  onChanged: onSortChanged,
                ),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 30, height: 30),
                  padding: EdgeInsets.zero,
                  tooltip: TransactionUiText.clearFilters,
                  onPressed: onResetFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                ),
              ],
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${TransactionUiText.resultCount} $resultCount',
              style: TextStyle(
                fontSize: 11,
                color: c.textSecondary,
                fontFamily: 'Kanit',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              footnote,
              style: TextStyle(
                fontSize: 10,
                height: 1.25,
                color: c.textHint,
                fontFamily: 'Kanit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
