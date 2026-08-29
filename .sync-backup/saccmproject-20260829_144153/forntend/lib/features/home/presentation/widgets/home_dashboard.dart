import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/thai_date_formatter.dart';
import 'package:saccm/features/home/presentation/providers/dashboard_provider.dart';
import 'package:saccm/features/home/presentation/widgets/compliance_alerts_card.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

/// Wrap ด้วย Provider แล้วแสดง dashboard
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    this.onOpenDepositRegister,
    this.onOpenReportsDailyClosing,
  });

  /// เปิดเมนูทะเบียนคุม แท็บเงินประกัน (index 6)
  final VoidCallback? onOpenDepositRegister;

  /// เปิดรายงาน → แท็บปิดวัน
  final VoidCallback? onOpenReportsDailyClosing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardProvider()..load(),
      child: _DashboardView(
        onOpenDepositRegister: onOpenDepositRegister,
        onOpenReportsDailyClosing: onOpenReportsDailyClosing,
      ),
    );
  }
}

// ─── View ─────────────────────────────────────────────────────────────────────

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    this.onOpenDepositRegister,
    this.onOpenReportsDailyClosing,
  });

  final VoidCallback? onOpenDepositRegister;
  final VoidCallback? onOpenReportsDailyClosing;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DashboardProvider>();
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (p.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }

    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: () => context.read<DashboardProvider>().load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcome(context, p, c),
            const SizedBox(height: AppTheme.sp16),
            if (p.hasDepositDueSoonAlert)
              _buildDepositDueSoonCard(context, p, c),
            if (p.hasDepositDueSoonAlert) const SizedBox(height: AppTheme.sp16),
            if (p.hasComplianceAlerts || !p.todayClosed)
              ComplianceAlertsCard(
                alerts: p.complianceAlerts,
                todayClosed: p.todayClosed,
                onOpenDailyClosing: onOpenReportsDailyClosing,
              ),
            if (p.hasComplianceAlerts || !p.todayClosed)
              const SizedBox(height: AppTheme.sp16),
            _buildSummaryRow(p, c),
            const SizedBox(height: AppTheme.sp16),
            _buildBarChart(p, c),
            const SizedBox(height: AppTheme.sp16),
            _buildNetBalance(p, c),
            const SizedBox(height: AppTheme.sp24),
          ],
        ),
      ),
    );
  }

  // ─── Welcome header ───────────────────────────────────────────────
  Widget _buildWelcome(BuildContext context, DashboardProvider p, AppColors c) {
    final now = DateTime.now();
    final dateStr = ThaiDateFormatter.formatFull(now);
    final primary = Theme.of(context).colorScheme.primary;
    final school = p.schoolProfile.name.trim();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.iconBgIncome,
            borderRadius: BorderRadius.circular(AppTheme.r12),
          ),
          child: Icon(Icons.dashboard_rounded, color: primary, size: 22),
        ),
        const SizedBox(width: AppTheme.sp12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TransactionUiText.systemOverview,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Kanit',
                ),
              ),
              if (school.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  school,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Kanit',
                  ),
                ),
              ],
              Text(
                dateStr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontFamily: 'Kanit',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDepositDueSoonCard(
    BuildContext context,
    DashboardProvider p,
    AppColors c,
  ) {
    final overdue = p.depositDueSoonOverdue;
    final upcoming = p.depositDueSoonUpcoming;
    final warn = overdue > 0;
    return Material(
      color: warn ? c.expenseRed.withValues(alpha: 0.08) : c.iconBgIncome,
      borderRadius: BorderRadius.circular(AppTheme.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.r12),
        onTap: onOpenDepositRegister,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sp12),
          child: Row(
            children: [
              Icon(
                warn ? Icons.warning_amber_rounded : Icons.schedule_outlined,
                color: warn ? c.expenseRed : c.navy,
              ),
              const SizedBox(width: AppTheme.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TransactionUiText.homeDepositDueSoonTitle,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      TransactionUiText.homeDepositDueSoonSummary(
                        overdue,
                        upcoming,
                      ),
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        color: c.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (onOpenDepositRegister != null)
                      Text(
                        TransactionUiText.homeDepositDueSoonTapHint,
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          color: c.navy.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Summary cards row ────────────────────────────────────────────
  Widget _buildSummaryRow(DashboardProvider p, AppColors c) {
    final fmt = NumberFormat('#,##0.00');
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.south_rounded,
            iconBg: c.iconBgIncome,
            iconColor: c.navy,
            label: TransactionUiText.totalIncomeLabelCard,
            value: '฿${fmt.format(p.totalIncome)}',
            subLabel: '${p.incomeCount} ${TransactionUiText.items}',
            valueColor: c.incomeGreen,
          ),
        ),
        const SizedBox(width: AppTheme.sp12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.north_rounded,
            iconBg: c.iconBgExpense,
            iconColor: c.expenseRed,
            label: TransactionUiText.totalExpenseLabelCard,
            value: '฿${fmt.format(p.totalExpense)}',
            subLabel: '${p.expenseCount} ${TransactionUiText.items}',
            valueColor: c.expenseRed,
          ),
        ),
      ],
    );
  }

  // ─── Bar chart ────────────────────────────────────────────────────
  Widget _buildBarChart(DashboardProvider p, AppColors c) {
    final data = p.monthlyData;
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVal = data.fold(0.0,
        (m, e) => [m, e.income, e.expense].reduce((a, b) => a > b ? a : b));
    final interval = maxVal > 0 ? (maxVal / 4).ceilToDouble() : 1000.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: c.navy, size: 18),
              const SizedBox(width: 6),
              Text(
                TransactionUiText.last6MonthsIncomeExpense,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp4),
          _buildLegend(c),
          const SizedBox(height: AppTheme.sp16),
          SizedBox(
            height: 200,
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
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 48,
                      getTitlesWidget: (value, _) => Text(
                        _shortNum(value),
                        style: TextStyle(fontSize: 10, color: c.textSecondary),
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
                            style:
                                TextStyle(fontSize: 10, color: c.textSecondary),
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
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: m.expense,
                        color: c.expenseRed,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
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
                      final fmt = NumberFormat('#,##0');
                      final label = rodIndex == 0
                          ? TransactionUiText.income
                          : TransactionUiText.expense;
                      return BarTooltipItem(
                        '$label\n฿${fmt.format(rod.toY)}',
                        TextStyle(
                          color: rodIndex == 0 ? c.incomeGreen : c.expenseRed,
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
    );
  }

  Widget _buildLegend(AppColors c) {
    return Row(
      children: [
        _LegendDot(color: c.incomeGreen, label: TransactionUiText.income),
        const SizedBox(width: AppTheme.sp16),
        _LegendDot(color: c.expenseRed, label: TransactionUiText.expense),
      ],
    );
  }

  // ─── Net balance card ─────────────────────────────────────────────
  Widget _buildNetBalance(DashboardProvider p, AppColors c) {
    final net = p.totalIncome - p.totalExpense;
    final fmt = NumberFormat('#,##0.00');
    final isPositive = net >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: isPositive ? c.iconBgIncome : c.iconBgExpense,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(
          color: isPositive
              ? c.incomeGreen.withValues(alpha: 0.3)
              : c.expenseRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPositive ? c.incomeGreen : c.expenseRed,
              borderRadius: BorderRadius.circular(AppTheme.r8),
            ),
            child: Icon(
              isPositive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.sp12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TransactionUiText.netBalance,
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
              Text(
                '${isPositive ? '+' : ''}฿${fmt.format(net)}',
                style: TextStyle(
                  color: isPositive ? c.incomeGreen : c.expenseRed,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  String _shortNum(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String subLabel;
  final Color valueColor;

  const _SummaryCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subLabel,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppTheme.r8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(subLabel, style: TextStyle(color: c.textHint, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ],
    );
  }
}
