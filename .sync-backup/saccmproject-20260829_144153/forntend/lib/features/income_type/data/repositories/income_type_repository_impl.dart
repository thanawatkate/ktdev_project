import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../domain/entities/income_type_entity.dart';
import '../../domain/entities/source_group.dart';
import '../../domain/repositories/income_type_repository.dart';
import '../datasources/income_type_remote_data_source.dart';

class IncomeTypeRepositoryImpl implements IncomeTypeRepository {
  IncomeTypeRepositoryImpl(
      {required IncomeTypeRemoteDataSource remoteDataSource});

  @override
  Future<Either<Failure, List<SourceGroup>>> getSourceGroups() async {
    return const Left(
      CacheFailure(message: 'อ่านประเภทเงินจาก local provider เท่านั้น'),
    );
  }

  @override
  Future<Either<Failure, String?>> createIncomeType({
    required String token,
    required IncomeTypeEntity incomeType,
  }) async {
    return const Left(
      CacheFailure(
        message: 'บันทึกหมวดรายรับต้องใช้ local provider และ background sync',
      ),
    );
  }
}
