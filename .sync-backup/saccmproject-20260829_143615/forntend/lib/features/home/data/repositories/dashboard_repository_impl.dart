import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/error/failures.dart';
import 'package:saccm/core/local_data_source/income_local_data_source.dart';
import 'package:saccm/core/local_data_source/expense_local_data_source.dart';
import 'package:saccm/core/utils/either.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';

import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  @override
  Future<Either<Failure, DashboardSummary>> getDashboardSummary() async {
    try {
      final incomeDs = ServiceLocator.instance.get<IncomeLocalDataSource>();
      final expenseDs = ServiceLocator.instance.get<ExpenseLocalDataSource>();
      final registerDs = RegisterLocalDataSource();

      final now = DateTime.now();
      final startMonthDate = DateTime(now.year, now.month - 5);
      final startMonth =
          '${startMonthDate.year}-${startMonthDate.month.toString().padLeft(2, '0')}';
      final batch = await Future.wait<dynamic>([
        incomeDs.getDashboardSummaryTotals(),
        expenseDs.getDashboardSummaryTotals(),
        incomeDs.getDashboardMonthlyTotals(startMonth: startMonth),
        expenseDs.getDashboardMonthlyTotals(startMonth: startMonth),
      ]);
      final incomeTotals = batch[0] as ({double total, int count});
      final expenseTotals = batch[1] as ({double total, int count});
      final incomeMonthly = batch[2] as Map<String, double>;
      final expenseMonthly = batch[3] as Map<String, double>;
      final monthlyData = _buildMonthly(incomeMonthly, expenseMonthly);

      int depositOverdue = 0;
      int depositUpcoming = 0;
      try {
        final dueRows = await registerDs.listDepositsDueSoon(
          withinDays: 30,
        );
        final today = now;
        final todayOnly = DateTime(today.year, today.month, today.day);
        for (final row in dueRows) {
          final due = DateTime.tryParse(row['due_date']?.toString() ?? '');
          if (due == null) continue;
          final dueOnly = DateTime(due.year, due.month, due.day);
          final days = dueOnly.difference(todayOnly).inDays;
          if (days < 0) {
            depositOverdue++;
          } else {
            depositUpcoming++;
          }
        }
      } catch (_) {}

      final today = now.toIso8601String().substring(0, 10);
      var todayClosed = false;
      try {
        todayClosed = await registerDs.isDailyClosed(today);
      } catch (_) {}

      return Right(
        DashboardSummary(
          totalIncome: incomeTotals.total,
          totalExpense: expenseTotals.total,
          incomeCount: incomeTotals.count,
          expenseCount: expenseTotals.count,
          monthlyData: monthlyData,
          depositDueSoonOverdue: depositOverdue,
          depositDueSoonUpcoming: depositUpcoming,
          todayClosed: todayClosed,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// สร้างข้อมูลยอดรวม 6 เดือนย้อนหลังจาก aggregate ใน SQLite
  List<MonthlyData> _buildMonthly(
    Map<String, double> incomeMonthly,
    Map<String, double> expenseMonthly,
  ) {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - 5 + i);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';

      return MonthlyData(
        label: TransactionUiText.thaiMonthShort[month.month],
        income: incomeMonthly[key] ?? 0,
        expense: expenseMonthly[key] ?? 0,
      );
    });
  }
}
