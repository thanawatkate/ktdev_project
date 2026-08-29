import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

/// Bar chart comparing monthly income vs expense for the fiscal year.
class ReportsMonthlyChart extends StatelessWidget {
  const ReportsMonthlyChart({
    super.key,
    required this.incomeByMonth,
    required this.expenseByMonth,
    required this.fiscalYearText,
  });

  final List incomeByMonth;
  final List expenseByMonth;
  final String fiscalYearText;

  static String _shortNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (incomeByMonth.isEmpty && expenseByMonth.isEmpty) {
      return const SizedBox.shrink();
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

    final data = sortedMonths.map((m) {
      final parts = m.split('-');
      final monthIdx = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
      final months = TransactionUiText.thaiMonthShort;
      final label = (monthIdx >= 1 && monthIdx < months.length)
          ? months[monthIdx]
          : m;
      final inc =
          double.tryParse(incomeMap[m]?['total']?.toString() ?? '0') ?? 0;
      final exp =
          double.tryParse(expenseMap[m]?['total']?.toString() ?? '0') ?? 0;
      return _MonthPoint(label: label, income: inc, expense: exp);
    }).toList();

    final maxVal = data.fold<double>(
      0,
      (m, p) => [m, p.income, p.expense].reduce((a, b) => a > b ? a : b),
    );
    final interval = maxVal > 0 ? maxVal / 4.0 : 250.0;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.reportPaperBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.navy,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${TransactionUiText.monthlySummaryFiscalYear}$fiscalYearText',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      fontSize: 15,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendDot(color: c.incomeGreen, label: TransactionUiText.income),
                const SizedBox(width: 16),
                _LegendDot(color: c.expenseRed, label: TransactionUiText.expense),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxVal > 0 ? maxVal * 1.2 : 1000,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: c.dividerColor,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: interval,
                        reservedSize: 48,
                        getTitlesWidget: (value, _) => Text(
                          _shortNum(value),
                          style: TextStyle(
                            fontSize: 10,
                            color: c.textSecondary,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              data[idx].label,
                              style: TextStyle(
                                fontSize: 10,
                                color: c.textSecondary,
                                fontFamily: 'Kanit',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(data.length, (i) {
                    final m = data[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: m.income,
                          color: c.incomeGreen,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: m.expense,
                          color: c.expenseRed,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                      barsSpace: 4,
                    );
                  }),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => c.cardWhite,
                      tooltipBorder: BorderSide(color: c.cardBorder),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final fmt = NumberFormat('#,##0.00');
                        final label = rodIndex == 0
                            ? TransactionUiText.income
                            : TransactionUiText.expense;
                        return BarTooltipItem(
                          '$label\n${fmt.format(rod.toY)}',
                          TextStyle(
                            color:
                                rodIndex == 0 ? c.incomeGreen : c.expenseRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Kanit',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPoint {
  const _MonthPoint({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'Kanit'),
        ),
      ],
    );
  }
}
