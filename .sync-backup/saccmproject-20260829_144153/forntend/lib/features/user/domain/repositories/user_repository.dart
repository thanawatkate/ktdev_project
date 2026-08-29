import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../entities/prefix.dart';
import '../entities/user_group.dart';

abstract class UserRepository {
  Future<Either<Failure, List<Prefix>>> getPrefixes();

  Future<Either<Failure, List<UserGroup>>> getUserGroups();

  Future<Either<Failure, void>> createUser({
    required String token,
    required String code,
    required String name,
    required String lastName,
    required String email,
    required String username,
    required String password,
    required String contactNumber,
    required String address,
    required String refPrefix,
    required String refUserGroup,
  });
}
