import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../entities/income_entity.dart';
import '../repositories/income_repository.dart';

class GetIncomeList implements UseCase<List<IncomeEntity>, NoParams> {
  final IncomeRepository repository;

  GetIncomeList(this.repository);

  @override
  Future<Either<Failure, List<IncomeEntity>>> call(NoParams params) {
    return repository.getIncomeList();
  }
}
