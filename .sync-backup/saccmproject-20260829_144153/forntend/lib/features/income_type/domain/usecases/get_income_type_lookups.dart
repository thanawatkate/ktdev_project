import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../entities/source_group.dart';
import '../repositories/income_type_repository.dart';

class GetSourceGroups implements UseCase<List<SourceGroup>, NoParams> {
  final IncomeTypeRepository repository;

  GetSourceGroups(this.repository);

  @override
  Future<Either<Failure, List<SourceGroup>>> call(NoParams params) {
    return repository.getSourceGroups();
  }
}
