import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../repositories/user_repository.dart';

class CreateUser implements UseCase<void, CreateUserParams> {
  final UserRepository repository;

  CreateUser(this.repository);

  @override
  Future<Either<Failure, void>> call(CreateUserParams params) {
    return repository.createUser(
      token: params.token,
      code: params.code,
      name: params.name,
      lastName: params.lastName,
      email: params.email,
      username: params.username,
      password: params.password,
      contactNumber: params.contactNumber,
      address: params.address,
      refPrefix: params.refPrefix,
      refUserGroup: params.refUserGroup,
    );
  }
}

class CreateUserParams {
  final String token;
  final String code;
  final String name;
  final String lastName;
  final String email;
  final String username;
  final String password;
  final String contactNumber;
  final String address;
  final String refPrefix;
  final String refUserGroup;

  const CreateUserParams({
    required this.token,
    required this.code,
    required this.name,
    required this.lastName,
    required this.email,
    required this.username,
    required this.password,
    required this.contactNumber,
    required this.address,
    required this.refPrefix,
    required this.refUserGroup,
  });
}
