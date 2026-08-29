import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_monthly_chart.dart';

class ReportsOverviewTab extends StatelessWidget {
  const ReportsOverviewTab({super.key, required this.summary});

  final Map<String, dynamic>? summary;

  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (summary == null) {
      return Center(
          child: Text(TransactionUiText.noData,
              style: TextStyle(color: c.textSecondary)));
    }
    final income = double.tryParse(summary!['total_income']?.toString() ?? '0') ?? 0;
    final expense = double.tryParse(summary!['total_expense']?.toString() ?? '0') ?? 0;
    final balance = double.tryParse(summary!['balance']?.toString() ?? '0') ?? 0;
    final loan = double.tryParse(summary!['total_loan']?.toString() ?? '0') ?? 0;
    final repay = double.tryParse(summary!['total_repay']?.toString() ?? '0') ?? 0;

    Widget summaryCard(
      String label,
      String value,
      String unit,
      Color color,
      IconData icon,
    ) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.reportPaper,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.reportPaperBorder),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: value,
                    style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
                TextSpan(text: '  $unit', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ]),
            ),
          ]),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        summaryCard(TransactionUiText.totalIncome, _fmt.format(income), TransactionUiText.baht,
            c.incomeGreen, Icons.south_rounded),
        const SizedBox(height: 10),
        summaryCard(TransactionUiText.totalExpense, _fmt.format(expense), TransactionUiText.baht,
            c.expenseRed, Icons.north_rounded),
        const SizedBox(height: 10),
        summaryCard(TransactionUiText.totalBalance, _fmt.format(balance), TransactionUiText.baht,
            balance >= 0 ? c.incomeGreen : Colors.red, Icons.account_balance_wallet_outlined),
        const SizedBox(height: 10),
        summaryCard(TransactionUiText.totalLoan, _fmt.format(loan), TransactionUiText.baht,
            c.loanAmber, Icons.account_balance_rounded),
        const SizedBox(height: 10),
        summaryCard(TransactionUiText.totalRepay, _fmt.format(repay), TransactionUiText.baht,
            c.navy, Icons.replay_rounded),
      ]),
    );
  }
}

class ReportsMonthlyTab extends StatelessWidget {
  const ReportsMonthlyTab({
    super.key,
    required this.incomeByMonth,
    required this.expenseByMonth,
    required this.fiscalYearText,
  });

  final List incomeByMonth;
  final List expenseByMonth;
  final String fiscalYearText;
  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (incomeByMonth.isEmpty && expenseByMonth.isEmpty) {
      return Center(
          child: Text(TransactionUiText.noData,
              style: TextStyle(color: c.textSecondary)));
    }
    final Set<String> months = {};
    for (final r in incomeByMonth) {
      months.add(r['month'] as String);
    }
    for (final r in expenseByMonth) {
      months.add(r['month'] as String);
    }
    final sortedMonths = months.toList()..sort();
    final incomeMap = {for (var r in incomeByMonth) r['month'] as String: r};
    final expenseMap = {for (var r in expenseByMonth) r['month'] as String: r};

    Widget miniStat(String label, String value, Color color) => Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary)),
            Text(value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        ReportsMonthlyChart(
          incomeByMonth: incomeByMonth,
          expenseByMonth: expenseByMonth,
          fiscalYearText: fiscalYearText,
        ),
        const SizedBox(height: 16),
        Row(children: [
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(color: c.navy, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('${TransactionUiText.monthlySummaryFiscalYear}$fiscalYearText',
              style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        ...sortedMonths.map((m) {
          final inc = double.tryParse(incomeMap[m]?['total']?.toString() ?? '0') ?? 0;
          final exp = double.tryParse(expenseMap[m]?['total']?.toString() ?? '0') ?? 0;
          final diff = inc - exp;
          final parts = m.split('-');
          final yearCe = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
          final thYear = yearCe > 0 ? yearCe + 543 : 0;
          final monthIdx = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
          final months = TransactionUiText.thaiMonthShort;
          final monthName = (monthIdx >= 1 && monthIdx < months.length)
              ? months[monthIdx]
              : m;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.reportPaper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.reportPaperBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  thYear > 0 ? '$monthName $thYear' : monthName,
                  style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                miniStat(TransactionUiText.receiveShort, _fmt.format(inc), c.incomeGreen),
                miniStat(TransactionUiText.payShort, _fmt.format(exp), c.expenseRed),
                miniStat(TransactionUiText.remaining, _fmt.format(diff),
                    diff >= 0 ? c.incomeGreen : Colors.red),
              ]),
            ]),
          );
        }),
      ]),
    );
  }
}

class ReportsBudgetSourceTab extends StatelessWidget {
  const ReportsBudgetSourceTab({super.key, required this.budgetData});
  final List budgetData;
  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (budgetData.isEmpty) {
      return Center(
          child: Text(TransactionUiText.noData,
              style: TextStyle(color: c.textSecondary)));
    }
    Widget miniStat(String label, String value, Color color) => Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary)),
            Text(value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        );
    final totalBudget = budgetData.fold<double>(0, (sum, item) {
      final y = double.tryParse(item['budget_amount']?.toString() ?? '0') ?? 0;
      final bf = double.tryParse(item['brought_forward_amount']?.toString() ?? '0') ?? 0;
      return sum + y + bf;
    });
    final totalIncome = budgetData.fold<double>(
      0,
      (sum, item) =>
          sum +
          (double.tryParse(item['income_amount']?.toString() ??
                  item['total_income']?.toString() ??
                  item['received_income']?.toString() ??
                  '0') ??
              0),
    );
    final totalUsed = budgetData.fold<double>(
      0,
      (sum, item) => sum + (double.tryParse(item['used_expense']?.toString() ?? '0') ?? 0),
    );
    final totalNetBalance = totalIncome - totalUsed;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: budgetData.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == budgetData.length) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.reportPaper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.reportPaperBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(TransactionUiText.reportsBudgetSourceTotalLabel,
                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                miniStat(TransactionUiText.allocated, _fmt.format(totalBudget), c.textSecondary),
                miniStat(TransactionUiText.totalIncome, _fmt.format(totalIncome), c.incomeGreen),
                miniStat(TransactionUiText.used, _fmt.format(totalUsed), c.expenseRed),
              ]),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${TransactionUiText.totalBalance}: ${_fmt.format(totalNetBalance)} ${TransactionUiText.baht}',
                  style: TextStyle(
                    fontSize: 12,
                    color: totalNetBalance >= 0 ? c.incomeGreen : c.expenseRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
          );
        }
        final item = budgetData[i];
        final budget = (double.tryParse(item['budget_amount']?.toString() ?? '0') ?? 0) +
            (double.tryParse(item['brought_forward_amount']?.toString() ?? '0') ?? 0);
        final incomeBySource = double.tryParse(item['income_amount']?.toString() ??
                item['total_income']?.toString() ??
                item['received_income']?.toString() ??
                '0') ??
            0;
        final used = double.tryParse(item['used_expense']?.toString() ?? '0') ?? 0;
        final remaining = item['remaining'] != null
            ? (double.tryParse(item['remaining']?.toString() ?? '') ?? (budget - used))
            : (budget - used);
        final netBalance = incomeBySource - used;
        final percent = budget > 0 ? used / budget : 0.0;
        final over = used > budget;
        final barColor = over ? Colors.red : (percent > 0.8 ? Colors.orange : c.navy);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.reportPaper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.reportPaperBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${item['code']} ', style: TextStyle(color: c.navy, fontWeight: FontWeight.w700)),
              Expanded(
                  child: Text(item['name'] ?? '',
                      style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              miniStat(TransactionUiText.budgetLimit, _fmt.format(budget), c.textSecondary),
              miniStat(TransactionUiText.totalIncome, _fmt.format(incomeBySource), c.incomeGreen),
              miniStat(TransactionUiText.used, _fmt.format(used), over ? Colors.red : c.expenseRed),
              miniStat(TransactionUiText.remaining, _fmt.format(remaining),
                  over ? Colors.red : c.incomeGreen),
            ]),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${TransactionUiText.totalBalance}: ${_fmt.format(netBalance)} ${TransactionUiText.baht}',
                style: TextStyle(
                    fontSize: 11,
                    color: netBalance >= 0 ? c.incomeGreen : c.expenseRed,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0).toDouble(),
                backgroundColor: c.cardBorder,
                color: barColor,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${double.tryParse(item['used_percent']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0'}${TransactionUiText.budgetUsedPercentSuffix}',
              style: TextStyle(fontSize: 11, color: c.textSecondary),
            ),
          ]),
        );
      },
    );
  }
}

class ReportsTrialBalanceTab extends StatelessWidget {
  const ReportsTrialBalanceTab({super.key, required this.trialBalance});
  final Map<String, dynamic>? trialBalance;
  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (trialBalance == null) {
      return Center(
          child: Text(TransactionUiText.noData,
              style: TextStyle(color: c.textSecondary)));
    }
    final incomeList = trialBalance!['income'] as List? ?? [];
    final expenseList = trialBalance!['expense'] as List? ?? [];
    final totalIncome = incomeList.fold<double>(
        0, (s, r) => s + (double.tryParse(r['total']?.toString() ?? '0') ?? 0));
    final totalExpense = expenseList.fold<double>(
        0, (s, r) => s + (double.tryParse(r['total']?.toString() ?? '0') ?? 0));

    Widget trialRow(String label, double amount, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13))),
            Text(_fmt.format(amount), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        );
    Widget totalRow(String label, double amount, Color color) => Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            Text(_fmt.format(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(color: c.navy, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(TransactionUiText.trialBalanceTab,
              style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        Text(TransactionUiText.income,
            style: TextStyle(fontWeight: FontWeight.w700, color: c.incomeGreen, fontSize: 15)),
        const SizedBox(height: 6),
        ...incomeList.map((r) => trialRow(
            r['type_name'] ?? TransactionUiText.unspecified,
            double.tryParse(r['total']?.toString() ?? '0') ?? 0,
            c.incomeGreen)),
        totalRow(TransactionUiText.totalIncomeLabel, totalIncome, c.incomeGreen),
        const SizedBox(height: 16),
        Text(TransactionUiText.expense,
            style: TextStyle(fontWeight: FontWeight.w700, color: c.expenseRed, fontSize: 15)),
        const SizedBox(height: 6),
        ...expenseList.map((r) => trialRow(
            r['type_name'] ?? TransactionUiText.unspecified,
            double.tryParse(r['total']?.toString() ?? '0') ?? 0,
            c.expenseRed)),
        totalRow(TransactionUiText.totalExpenseLabel, totalExpense, c.expenseRed),
        const Divider(height: 24),
        totalRow(TransactionUiText.netProfitLoss, totalIncome - totalExpense,
            totalIncome >= totalExpense ? c.incomeGreen : Colors.red),
      ]),
    );
  }
}

class ReportsBudgetRemainingTab extends StatelessWidget {
  const ReportsBudgetRemainingTab({super.key, required this.budgetRemaining});
  final List budgetRemaining;
  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (budgetRemaining.isEmpty) {
      return Center(
          child: Text(TransactionUiText.noData,
              style: TextStyle(color: c.textSecondary)));
    }
    Widget miniStat(String label, String value, Color color) => Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary)),
            Text(value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        );
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: budgetRemaining.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = budgetRemaining[i];
        final budget = (double.tryParse(item['budget_amount']?.toString() ?? '0') ?? 0) +
            (double.tryParse(item['brought_forward_amount']?.toString() ?? '0') ?? 0);
        final used = double.tryParse(item['used_amount']?.toString() ?? '0') ?? 0;
        final remaining =
            double.tryParse(item['remaining']?.toString() ?? '0') ?? (budget - used);
        final percent = double.tryParse(item['used_percent']?.toString() ?? '0') ?? 0;
        final over = remaining < 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.reportPaper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: over ? Colors.red.withValues(alpha: 0.4) : c.reportPaperBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${item['code']} ${item['name']}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
              ),
              if (over)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(TransactionUiText.overBudget,
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              miniStat(TransactionUiText.allocated, _fmt.format(budget), c.textSecondary),
              miniStat(TransactionUiText.used, _fmt.format(used), c.expenseRed),
              miniStat(TransactionUiText.remaining, _fmt.format(remaining),
                  over ? Colors.red : c.incomeGreen),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                backgroundColor: c.cardBorder,
                color: over ? Colors.red : (percent > 80 ? Colors.orange : c.navy),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text('${TransactionUiText.usedPercentPrefix}${percent.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ]),
        );
      },
    );
  }
}
