import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../domain/entities/prefix.dart';
import '../../domain/entities/user_group.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({required UserRemoteDataSource remoteDataSource});

  @override
  Future<Either<Failure, List<Prefix>>> getPrefixes() async {
    return const Left(
      CacheFailure(message: 'อ่านคำนำหน้าจาก local provider เท่านั้น'),
    );
  }

  @override
  Future<Either<Failure, List<UserGroup>>> getUserGroups() async {
    return const Left(
      CacheFailure(message: 'อ่านกลุ่มผู้ใช้จาก local provider เท่านั้น'),
    );
  }

  @override
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
  }) async {
    return const Left(
      CacheFailure(message: 'บันทึกผู้ใช้ต้องใช้ local data source เท่านั้น'),
    );
  }
}
