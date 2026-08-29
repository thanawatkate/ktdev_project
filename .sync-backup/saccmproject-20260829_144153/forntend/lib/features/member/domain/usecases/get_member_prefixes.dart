import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../entities/prefix.dart';
import '../repositories/member_repository.dart';

class GetMemberPrefixes implements UseCase<List<Prefix>, NoParams> {
  final MemberRepository repository;

  GetMemberPrefixes(this.repository);

  @override
  Future<Either<Failure, List<Prefix>>> call(NoParams params) {
    return repository.getPrefixes();
  }
}
