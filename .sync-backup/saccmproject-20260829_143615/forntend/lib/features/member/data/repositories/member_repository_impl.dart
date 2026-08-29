import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../domain/entities/prefix.dart';
import '../../domain/entities/member_entity.dart';
import '../../domain/repositories/member_repository.dart';
import '../datasources/member_remote_data_source.dart';

class MemberRepositoryImpl implements MemberRepository {
  MemberRepositoryImpl({required MemberRemoteDataSource remoteDataSource});

  @override
  Future<Either<Failure, List<Prefix>>> getPrefixes() async {
    return const Left(
      CacheFailure(message: 'อ่านคำนำหน้าจาก local repository เท่านั้น'),
    );
  }

  @override
  Future<Either<Failure, void>> createMember({
    required String token,
    required MemberEntity member,
  }) async {
    return const Left(
      CacheFailure(message: 'บันทึกสมาชิกต้องใช้ offline repository เท่านั้น'),
    );
  }
}
