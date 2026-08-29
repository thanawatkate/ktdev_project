import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../entities/prefix.dart';
import '../entities/user_group.dart';
import '../repositories/user_repository.dart';

class GetUserPrefixes implements UseCase<List<Prefix>, NoParams> {
  final UserRepository repository;

  GetUserPrefixes(this.repository);

  @override
  Future<Either<Failure, List<Prefix>>> call(NoParams params) {
    return repository.getPrefixes();
  }
}

class GetUserGroups implements UseCase<List<UserGroup>, NoParams> {
  final UserRepository repository;

  GetUserGroups(this.repository);

  @override
  Future<Either<Failure, List<UserGroup>>> call(NoParams params) {
    return repository.getUserGroups();
  }
}
