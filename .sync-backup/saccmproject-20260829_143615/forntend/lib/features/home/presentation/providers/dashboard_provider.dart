import 'package:flutter/material.dart';
import 'package:saccm/core/error/failures.dart';
import 'package:saccm/core/usecases/usecase.dart';
import 'package:saccm/core/utils/either.dart';
import 'package:saccm/features/home/data/repositories/dashboard_repository_impl.dart';
import 'package:saccm/features/home/domain/usecases/get_dashboard_summary.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';

import '../../domain/entities/compliance_alert.dart';
import '../../domain/entities/dashboard_summary.dart';

class DashboardProvider extends ChangeNotifier {
  late final GetDashboardSummary _getDashboardSummary;
  final SchoolProfileLocalDataSource _schoolProfileDs =
      SchoolProfileLocalDataSourceImpl();

  DashboardSummary? _summary;
  SchoolProfile _schoolProfile = const SchoolProfile();
  bool isLoading = false;
  String? error;

  bool _disposed = false;

  DashboardProvider() {
    final repository = DashboardRepositoryImpl();
    _getDashboardSummary = GetDashboardSummary(repository);
  }

  DashboardSummary? get summary => _summary;
  SchoolProfile get schoolProfile => _schoolProfile;
  double get totalIncome => _summary?.totalIncome ?? 0;
  double get totalExpense => _summary?.totalExpense ?? 0;
  int get incomeCount => _summary?.incomeCount ?? 0;
  int get expenseCount => _summary?.expenseCount ?? 0;
  List<MonthlyData> get monthlyData => _summary?.monthlyData ?? [];
  int get depositDueSoonOverdue => _summary?.depositDueSoonOverdue ?? 0;
  int get depositDueSoonUpcoming => _summary?.depositDueSoonUpcoming ?? 0;
  bool get hasDepositDueSoonAlert => _summary?.hasDepositDueSoonAlert ?? false;
  List<ComplianceAlert> get complianceAlerts =>
      _summary?.complianceAlerts ?? const [];
  bool get hasComplianceAlerts => _summary?.hasComplianceAlerts ?? false;
  bool get todayClosed => _summary?.todayClosed ?? false;
  int get criticalAlertCount => _summary?.criticalAlertCount ?? 0;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    if (!_disposed) notifyListeners();

    final batch = await Future.wait<dynamic>([
      _getDashboardSummary.call(NoParams()),
      _schoolProfileDs.load(),
    ]);
    final result = batch[0] as Either<Failure, DashboardSummary>;
    _schoolProfile = batch[1] as SchoolProfile;

    result.fold(
      (failure) {
        error = failure.message;
      },
      (summary) {
        _summary = summary;
      },
    );

    isLoading = false;
    if (!_disposed) notifyListeners();
  }
}
