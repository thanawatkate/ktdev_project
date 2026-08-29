import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../entities/income_entity.dart';
import '../entities/lookup_item.dart';

abstract class IncomeRepository {
  Future<Either<Failure, List<IncomeEntity>>> getIncomeList();

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
  });

  /// ลบ income แบบ offline-first: ลบ local ทันที + คิว DELETE `/income/:id`
  Future<Either<Failure, void>> deleteIncomeOfflineFirst({
    required String localId,
    required String token,
  });

  Future<Either<Failure, List<LookupItem>>> getMoneyTypes();

  Future<Either<Failure, List<LookupItem>>> getIncomeTypes();

  Future<Either<Failure, List<LookupItem>>> getBudgetSources();

  Future<Either<Failure, List<LookupItem>>> getBudgetSourcesForIncomeType(
    String incomeTypeId,
  );

  Future<Either<Failure, LookupItem?>> getBudgetSourceById(
    String budgetSourceId,
  );

  Future<Either<Failure, List<LookupItem>>> getParties();

  /// รายชื่อผู้จ่ายจาก localdb (ตาราง `party` + ชื่อจาก income ที่ยังไม่มีใน master) — ไม่เรียกเซิร์ฟเวอร์
  Future<Either<Failure, List<LookupItem>>> getPartiesFromLocalIncome();

  /// แถวผู้จ่ายสำหรับ picker (id, name, role, isactive) จาก localdb เท่านั้น
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getPayerPartyRowsLocalForPicker();

  /// บันทึกผลจาก `/party` ลงตาราง `party` ใน SQLite (ฝั่ง offline เท่านั้น)
  Future<void> cachePartyMasterRowsFromServer(List<Map<String, dynamic>> rows);

  /// ดึงรายการ party ที่ active จากเซิร์ฟเวอร์แล้วอัปเดตตาราง `party` ใน localdb
  Future<void> refreshPartyMasterCacheFromServer();

  /// สร้างผู้รับ/ผู้จ่ายแบบ offline-first: บันทึก SQLite ก่อน แล้วคิว POST `/party`
  /// คืน `id` ชั่วคราวใน localdb (รูปแบบ `lp_...`)
  Future<String> createPartyOfflineFirst({
    required String token,
    int? actorId,
    String? actorName,
    required String name,
    required String role,
    String phone = '',
    String taxid = '',
    String remark = '',
  });

  /// แก้ไข party: อัปเดต SQLite ทันที แล้วคิว POST (ถ้า id เป็น `lp_...`) หรือ PATCH
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
  });

  /// สลับสถานะใช้งาน: อัปเดต local แล้วคิว PATCH (เฉพาะ id ที่ซิงก์จากเซิร์ฟเวอร์แล้ว)
  Future<void> setPartyActiveOfflineFirst({
    required String partyId,
    required String token,
    int? actorId,
    String? actorName,
    required bool isActive,
  });

  /// ลบผู้เกี่ยวข้อง: ลบ SQLite + ตัด refParty แล้วคิว DELETE `/party/:id` (ยกเว้น id แบบ `lp_` ที่ยังไม่ขึ้นเซิร์ฟเวอร์)
  Future<void> deletePartyOfflineFirst({
    required String partyId,
    required String token,
    int? actorId,
    String? actorName,
  });

  Future<Either<Failure, String>> getDocNo({
    required String tableName,
    required String docDate,
  });

  /// เล่มใบเสร็จที่สถานะพร้อมใช้ (อ่านจาก SQLite)
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getAvailableReceiptBooks();

  Future<Either<Failure, String?>> getSuggestedNextReceiptNo(String bookId);
}
