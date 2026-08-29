import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../entities/member_entity.dart';
import '../repositories/member_repository.dart';

class CreateMember implements UseCase<void, CreateMemberParams> {
  final MemberRepository repository;

  CreateMember(this.repository);

  @override
  Future<Either<Failure, void>> call(CreateMemberParams params) {
    return repository.createMember(
      token: params.token,
      member: params.member,
    );
  }
}

class CreateMemberParams {
  final String token;
  final MemberEntity member;

  const CreateMemberParams({required this.token, required this.member});
}
