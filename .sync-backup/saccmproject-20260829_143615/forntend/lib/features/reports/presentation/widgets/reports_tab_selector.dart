import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

const int reportTabCount = 12;

class ReportTabInfo {
  const ReportTabInfo({
    required this.index,
    required this.label,
    required this.groupLabel,
    required this.description,
    required this.icon,
  });

  final int index;
  final String label;
  final String groupLabel;
  final String description;
  final IconData icon;
}

const List<ReportTabInfo> reportTabItems = [
  ReportTabInfo(
    index: 0,
    label: TransactionUiText.overviewTab,
    groupLabel: TransactionUiText.reportsMenuGroupSummary,
    description: TransactionUiText.reportsDescOverview,
    icon: Icons.dashboard_outlined,
  ),
  ReportTabInfo(
    index: 1,
    label: TransactionUiText.monthlyTab,
    groupLabel: TransactionUiText.reportsMenuGroupSummary,
    description: TransactionUiText.reportsDescMonthly,
    icon: Icons.calendar_month_outlined,
  ),
  ReportTabInfo(
    index: 5,
    label: TransactionUiText.annualSummaryTab,
    groupLabel: TransactionUiText.reportsMenuGroupSummary,
    description: TransactionUiText.reportsDescAnnualSummary,
    icon: Icons.summarize_outlined,
  ),
  ReportTabInfo(
    index: 2,
    label: TransactionUiText.budgetSourceTab,
    groupLabel: TransactionUiText.reportsMenuGroupBudget,
    description: TransactionUiText.reportsDescBudgetSource,
    icon: Icons.account_tree_outlined,
  ),
  ReportTabInfo(
    index: 3,
    label: TransactionUiText.trialBalanceTab,
    groupLabel: TransactionUiText.reportsMenuGroupBudget,
    description: TransactionUiText.reportsDescTrialBalance,
    icon: Icons.balance_outlined,
  ),
  ReportTabInfo(
    index: 4,
    label: TransactionUiText.budgetRemainingTab,
    groupLabel: TransactionUiText.reportsMenuGroupBudget,
    description: TransactionUiText.reportsDescBudgetRemaining,
    icon: Icons.savings_outlined,
  ),
  ReportTabInfo(
    index: 6,
    label: TransactionUiText.dailyBalanceTab,
    groupLabel: TransactionUiText.reportsMenuGroupOfficial,
    description: TransactionUiText.reportsDescDailyBalance,
    icon: Icons.account_balance_wallet_outlined,
  ),
  ReportTabInfo(
    index: 7,
    label: TransactionUiText.dailyCashSummaryTab,
    groupLabel: TransactionUiText.reportsMenuGroupOfficial,
    description: TransactionUiText.reportsDescDailyCashSummary,
    icon: Icons.payments_outlined,
  ),
  ReportTabInfo(
    index: 8,
    label: TransactionUiText.bankReconciliationTab,
    groupLabel: TransactionUiText.reportsMenuGroupOfficial,
    description: TransactionUiText.reportsDescBankReconciliation,
    icon: Icons.account_balance_outlined,
  ),
  ReportTabInfo(
    index: 9,
    label: TransactionUiText.dailyClosingTab,
    groupLabel: TransactionUiText.reportsMenuGroupControl,
    description: TransactionUiText.reportsDescDailyClosing,
    icon: Icons.lock_clock_outlined,
  ),
  ReportTabInfo(
    index: 10,
    label: TransactionUiText.loanOutstandingTab,
    groupLabel: TransactionUiText.reportsMenuGroupControl,
    description: TransactionUiText.reportsDescLoanOutstanding,
    icon: Icons.assignment_late_outlined,
  ),
  ReportTabInfo(
    index: 11,
    label: TransactionUiText.chequeOutstandingTab,
    groupLabel: TransactionUiText.reportsMenuGroupControl,
    description: TransactionUiText.reportsDescChequeOutstanding,
    icon: Icons.receipt_long_outlined,
  ),
];

const List<String> reportTabGroupLabels = [
  TransactionUiText.reportsMenuGroupSummary,
  TransactionUiText.reportsMenuGroupBudget,
  TransactionUiText.reportsMenuGroupOfficial,
  TransactionUiText.reportsMenuGroupControl,
];

ReportTabInfo reportTabInfoAt(int index) {
  return reportTabItems.firstWhere(
    (item) => item.index == index,
    orElse: () => reportTabItems.first,
  );
}

class ReportsTabSelector extends StatelessWidget {
  const ReportsTabSelector({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    this.showHint = true,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final currentTab = reportTabInfoAt(currentIndex);
    final groupReports = reportTabItems
        .where((item) => item.groupLabel == currentTab.groupLabel)
        .toList();

    final groupField = AppDropdownField<String>(
      label: TransactionUiText.reportsSelectGroupLabel,
      value: currentTab.groupLabel,
      density: AppDropdownDensity.compact,
      prefixIcon: const Icon(Icons.folder_outlined),
      items: reportTabGroupLabels
          .map(
            (label) => AppDropdownItem<String>(
              value: label,
              label: label,
              leadingIcon:
                  Icon(Icons.folder_open_outlined, size: 18, color: c.navy),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null || value == currentTab.groupLabel) return;
        final firstInGroup = reportTabItems.firstWhere(
          (item) => item.groupLabel == value,
          orElse: () => reportTabItems.first,
        );
        onChanged(firstInGroup.index);
      },
    );

    final reportField = AppDropdownField<int>(
      label: TransactionUiText.reportsSelectReportLabel,
      value: currentIndex,
      density: AppDropdownDensity.compact,
      prefixIcon: const Icon(Icons.dashboard_customize_outlined),
      items: groupReports
          .map(
            (item) => AppDropdownItem<int>(
              value: item.index,
              label: item.label,
              leadingIcon: Icon(item.icon, size: 18, color: c.navy),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackFields = constraints.maxWidth < 460;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stackFields) ...[
              groupField,
              const SizedBox(height: AppTheme.sp8),
              reportField,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(flex: 4, child: groupField),
                  const SizedBox(width: AppTheme.sp8),
                  Expanded(flex: 5, child: reportField),
                ],
              ),
            if (showHint) ...[
              const SizedBox(height: AppTheme.sp8),
              ReportsSelectedReportHint(currentIndex: currentIndex),
            ],
          ],
        );
      },
    );
  }
}

class ReportsSelectedReportHint extends StatelessWidget {
  const ReportsSelectedReportHint({
    super.key,
    required this.currentIndex,
  });

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final currentTab = reportTabInfoAt(currentIndex);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: c.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.navy.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(currentTab.icon, size: 18, color: c.navy),
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${TransactionUiText.reportsCurrentReportPrefix}: ${currentTab.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontFamily: 'Kanit',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppTheme.sp4),
                Text(
                  currentTab.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'Kanit',
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.sp8),
          Text(
            '${TransactionUiText.reportsSequencePrefix} ${currentIndex + 1} '
            '${TransactionUiText.reportsSequenceMiddle} $reportTabCount',
            style: TextStyle(
              color: c.navy,
              fontFamily: 'Kanit',
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
