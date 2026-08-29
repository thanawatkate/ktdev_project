import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../entities/income_type_entity.dart';
import '../repositories/income_type_repository.dart';

class CreateIncomeType implements UseCase<String?, CreateIncomeTypeParams> {
  final IncomeTypeRepository repository;

  CreateIncomeType(this.repository);

  @override
  Future<Either<Failure, String?>> call(CreateIncomeTypeParams params) {
    return repository.createIncomeType(
      token: params.token,
      incomeType: params.incomeType,
    );
  }
}

class CreateIncomeTypeParams {
  final String token;
  final IncomeTypeEntity incomeType;

  const CreateIncomeTypeParams({
    required this.token,
    required this.incomeType,
  });
}
