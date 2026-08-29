import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../entities/lookup_item.dart';
import '../repositories/income_repository.dart';

class GetMoneyTypes implements UseCase<List<LookupItem>, NoParams> {
  final IncomeRepository repository;

  GetMoneyTypes(this.repository);

  @override
  Future<Either<Failure, List<LookupItem>>> call(NoParams params) {
    return repository.getMoneyTypes();
  }
}

class GetIncomeTypes implements UseCase<List<LookupItem>, NoParams> {
  final IncomeRepository repository;

  GetIncomeTypes(this.repository);

  @override
  Future<Either<Failure, List<LookupItem>>> call(NoParams params) {
    return repository.getIncomeTypes();
  }
}

class GetBudgetSources implements UseCase<List<LookupItem>, NoParams> {
  final IncomeRepository repository;

  GetBudgetSources(this.repository);

  @override
  Future<Either<Failure, List<LookupItem>>> call(NoParams params) {
    return repository.getBudgetSources();
  }
}

class GetBudgetSourcesForIncomeType
    implements UseCase<List<LookupItem>, BudgetSourcesForIncomeTypeParams> {
  final IncomeRepository repository;

  GetBudgetSourcesForIncomeType(this.repository);

  @override
  Future<Either<Failure, List<LookupItem>>> call(
    BudgetSourcesForIncomeTypeParams params,
  ) {
    return repository.getBudgetSourcesForIncomeType(params.incomeTypeId);
  }
}

class GetBudgetSourceById
    implements UseCase<LookupItem?, BudgetSourceByIdParams> {
  final IncomeRepository repository;

  GetBudgetSourceById(this.repository);

  @override
  Future<Either<Failure, LookupItem?>> call(BudgetSourceByIdParams params) {
    return repository.getBudgetSourceById(params.budgetSourceId);
  }
}

class BudgetSourcesForIncomeTypeParams {
  const BudgetSourcesForIncomeTypeParams(this.incomeTypeId);

  final String incomeTypeId;
}

class BudgetSourceByIdParams {
  const BudgetSourceByIdParams(this.budgetSourceId);

  final String budgetSourceId;
}
