import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

/// แถบค้นหาและตัวกรองแหล่งเงิน — จัดเป็นกลุ่มในการ์ดเดียว รองรับจอแคบ/กว้าง
class BudgetSourceFilterSection extends StatelessWidget {
  final String searchQuery;
  final String yearFilter;
  final String sortBy;
  final List<String> yearOptions;
  final bool hasActiveFilter;
  final int resultCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onYearChanged;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onResetFilters;

  const BudgetSourceFilterSection({
    super.key,
    required this.searchQuery,
    required this.yearFilter,
    required this.sortBy,
    required this.yearOptions,
    required this.hasActiveFilter,
    required this.resultCount,
    required this.onSearchChanged,
    required this.onYearChanged,
    required this.onSortChanged,
    required this.onResetFilters,
  });

  static const _sortItems = [
    AppDropdownItem(
      value: 'year_desc',
      label: 'ปีงบประมาณ: ใหม่ไปเก่า',
    ),
    AppDropdownItem(
      value: 'year_asc',
      label: 'ปีงบประมาณ: เก่าไปใหม่',
    ),
    AppDropdownItem(
      value: 'remaining_desc',
      label: TransactionUiText.budgetSourceSortRemainingAvailable,
    ),
    AppDropdownItem(
      value: 'name_asc',
      label: 'ชื่อ: A-Z',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.surfaceContainerHighest.withValues(alpha: 0.32);

    Widget searchField() {
      return TextFormField(
        key: ValueKey('budget_search_$searchQuery'),
        initialValue: searchQuery,
        decoration: InputDecoration(
          filled: true,
          fillColor: fill,
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: TransactionUiText.search,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.r12),
            borderSide: BorderSide(color: c.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.r12),
            borderSide: BorderSide(color: c.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.r12),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: onSearchChanged,
      );
    }

    Widget yearDropdown() {
      return AppDropdownField<String>(
        key: ValueKey('year_filter_$yearFilter'),
        density: AppDropdownDensity.compact,
        label: TransactionUiText.fiscalYearBuddhist,
        value: yearFilter,
        items: yearOptions
            .map(
              (y) => AppDropdownItem(
                value: y,
                label: y == 'all' ? TransactionUiText.budgetSourceFilterAllYears : y,
              ),
            )
            .toList(),
        onChanged: onYearChanged,
      );
    }

    Widget sortDropdown() {
      return AppDropdownField<String>(
        key: ValueKey('sort_filter_$sortBy'),
        density: AppDropdownDensity.compact,
        label: TransactionUiText.budgetSourceSortLabel,
        value: sortBy,
        items: _sortItems,
        onChanged: onSortChanged,
      );
    }

    Widget clearButton() {
      return OutlinedButton.icon(
        onPressed: onResetFilters,
        icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
        label: const Text(TransactionUiText.clearFilters),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: c.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.r12),
          side: BorderSide(color: c.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.manage_search_rounded, size: 22, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          TransactionUiText.budgetSourceFilterSectionTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (hasActiveFilter)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            TransactionUiText.budgetSourceFilterActiveHint,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (wide) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: searchField()),
                        const SizedBox(width: 12),
                        SizedBox(width: 168, child: yearDropdown()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: sortDropdown()),
                        if (hasActiveFilter) ...[
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: clearButton(),
                          ),
                        ],
                      ],
                    ),
                  ] else ...[
                    searchField(),
                    const SizedBox(height: 12),
                    yearDropdown(),
                    const SizedBox(height: 12),
                    sortDropdown(),
                    if (hasActiveFilter) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: clearButton(),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: c.cardBorder),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.list_alt_rounded, size: 18, color: c.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${TransactionUiText.resultCount}: $resultCount ${TransactionUiText.items}',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
