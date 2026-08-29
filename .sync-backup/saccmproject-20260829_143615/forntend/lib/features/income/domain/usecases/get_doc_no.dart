import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../repositories/income_repository.dart';

class GetDocNo implements UseCase<String, GetDocNoParams> {
  final IncomeRepository repository;

  GetDocNo(this.repository);

  @override
  Future<Either<Failure, String>> call(GetDocNoParams params) {
    return repository.getDocNo(
      tableName: params.tableName,
      docDate: params.docDate,
    );
  }
}

class GetDocNoParams {
  final String tableName;
  final String docDate;

  const GetDocNoParams({required this.tableName, required this.docDate});
}
