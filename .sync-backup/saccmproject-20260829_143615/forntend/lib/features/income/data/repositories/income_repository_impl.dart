import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../domain/entities/income_entity.dart';
import '../../domain/entities/lookup_item.dart';
import '../../domain/repositories/income_repository.dart';
import '../datasources/income_remote_data_source.dart';

class IncomeRepositoryImpl implements IncomeRepository {
  IncomeRepositoryImpl({required IncomeRemoteDataSource remoteDataSource});

  @override
  Future<Either<Failure, List<IncomeEntity>>> getIncomeList() async {
    return const Left(
        CacheFailure(message: 'อ่านรายรับจาก local repository เท่านั้น'));
  }

  @override
  Future<Either<Failure, void>> createIncome({
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    String? bankReference,
    required String partyName,
    String? refParty,
    required String refUser,
    required String refMoneyType,
    required String refIncomeType,
    required String? refBudgetSource,
    required List<Map<String, dynamic>> subData,
    String? refBankAccount,
    String? receiptBookId,
    String? receiptNo,
    bool bumpBudgetSourceBudgetAmount = true,
    String docStatus = 'posted',
  }) async {
    return const Left(
      CacheFailure(message: 'บันทึกรายรับต้องใช้ offline repository เท่านั้น'),
    );
  }

  @override
  Future<Either<Failure, void>> deleteIncomeOfflineFirst({
    required String localId,
    required String token,
  }) async {
    return const Left(
      CacheFailure(
        message: 'deleteIncomeOfflineFirst requires offline IncomeRepository',
      ),
    );
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getMoneyTypes() async {
    return const Left(
        CacheFailure(message: 'อ่าน lookup จาก local repository เท่านั้น'));
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getIncomeTypes() async {
    return const Left(
        CacheFailure(message: 'อ่าน lookup จาก local repository เท่านั้น'));
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getBudgetSources() async {
    return const Left(
        CacheFailure(message: 'อ่านแหล่งเงินจาก local repository เท่านั้น'));
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getBudgetSourcesForIncomeType(
    String incomeTypeId,
  ) async {
    return const Left(
        CacheFailure(message: 'อ่านแหล่งเงินจาก local repository เท่านั้น'));
  }

  @override
  Future<Either<Failure, LookupItem?>> getBudgetSourceById(
    String budgetSourceId,
  ) async {
    return const Left(
        CacheFailure(message: 'อ่านแหล่งเงินจาก local repository เท่านั้น'));
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getParties() async {
    return const Left(
        CacheFailure(message: 'อ่านคู่ค้าจาก local repository เท่านั้น'));
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getPartiesFromLocalIncome() async {
    return const Right(<LookupItem>[]);
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getPayerPartyRowsLocalForPicker() async {
    return const Right(<Map<String, dynamic>>[]);
  }

  @override
  Future<void> cachePartyMasterRowsFromServer(
      List<Map<String, dynamic>> rows) async {}

  @override
  Future<void> refreshPartyMasterCacheFromServer() async {}

  @override
  Future<String> createPartyOfflineFirst({
    required String token,
    int? actorId,
    String? actorName,
    required String name,
    required String role,
    String phone = '',
    String taxid = '',
    String remark = '',
  }) {
    throw UnsupportedError(
        'createPartyOfflineFirst requires offline IncomeRepository');
  }

  @override
  Future<void> updatePartyOfflineFirst({
    required String partyId,
    required String token,
    int? actorId,
    String? actorName,
    required String name,
    required String role,
    String phone = '',
    String taxid = '',
    String remark = '',
  }) {
    throw UnsupportedError(
        'updatePartyOfflineFirst requires offline IncomeRepository');
  }

  @override
  Future<void> setPartyActiveOfflineFirst({
    required String partyId,
    required String token,
    int? actorId,
    String? actorName,
    required bool isActive,
  }) =>
      throw UnsupportedError(
          'setPartyActiveOfflineFirst requires offline IncomeRepository');

  @override
  Future<void> deletePartyOfflineFirst({
    required String partyId,
    required String token,
    int? actorId,
    String? actorName,
  }) =>
      throw UnsupportedError(
          'deletePartyOfflineFirst requires offline IncomeRepository');

  @override
  Future<Either<Failure, String>> getDocNo({
    required String tableName,
    required String docDate,
  }) async {
    return const Left(
        CacheFailure(message: 'สร้างเลขเอกสารจาก local repository เท่านั้น'));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getAvailableReceiptBooks() async {
    return const Right(<Map<String, dynamic>>[]);
  }

  @override
  Future<Either<Failure, String?>> getSuggestedNextReceiptNo(
    String bookId,
  ) async {
    return const Right(null);
  }
}
