/// รหัส `expense_type.code` ที่ระบบ seed ให้ผูกแหล่งเงิน master **GOV** (งบแผ่นดิน)
///
/// ใช้ร่วมกันใน:
/// - `AppDatabase._seedDefaultCategoryBudgetSourceLinks`
/// - `ExpenseBudgetSourceRule` (กรอง dropdown แหล่งเงินหน้าบันทึกรายจ่าย)
abstract final class GovExpenseTypeCodes {
  GovExpenseTypeCodes._();

  static const Set<String> linkedToGovMaster = <String>{
    '00',
    '04',
    '05',
    '06',
  };
}
