import 'compliance_alert.dart';

class DashboardSummary {
  final double totalIncome;
  final double totalExpense;
  final int incomeCount;
  final int expenseCount;
  final List<MonthlyData> monthlyData;
  final int depositDueSoonOverdue;
  final int depositDueSoonUpcoming;
  final List<ComplianceAlert> complianceAlerts;
  final bool todayClosed;

  DashboardSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.incomeCount,
    required this.expenseCount,
    required this.monthlyData,
    this.depositDueSoonOverdue = 0,
    this.depositDueSoonUpcoming = 0,
    this.complianceAlerts = const [],
    this.todayClosed = false,
  });

  bool get hasDepositDueSoonAlert =>
      depositDueSoonOverdue > 0 || depositDueSoonUpcoming > 0;

  bool get hasComplianceAlerts => complianceAlerts.isNotEmpty;

  int get criticalAlertCount =>
      complianceAlerts.where((a) => a.isCritical).length;

  double get netBalance => totalIncome - totalExpense;

  bool get isPositive => netBalance >= 0;
}

class MonthlyData {
  final String label;
  final double income;
  final double expense;

  MonthlyData({
    required this.label,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}
