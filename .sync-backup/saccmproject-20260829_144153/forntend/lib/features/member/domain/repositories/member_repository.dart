import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../entities/prefix.dart';
import '../entities/member_entity.dart';

abstract class MemberRepository {
  Future<Either<Failure, List<Prefix>>> getPrefixes();

  Future<Either<Failure, void>> createMember({
    required String token,
    required MemberEntity member,
  });
}
