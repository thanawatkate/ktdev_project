import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../entities/dashboard_summary.dart';

abstract class DashboardRepository {
  Future<Either<Failure, DashboardSummary>> getDashboardSummary();
}
