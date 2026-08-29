import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../entities/income_type_entity.dart';
import '../entities/source_group.dart';

abstract class IncomeTypeRepository {
  Future<Either<Failure, List<SourceGroup>>> getSourceGroups();

  Future<Either<Failure, String?>> createIncomeType({
    required String token,
    required IncomeTypeEntity incomeType,
  });
}
