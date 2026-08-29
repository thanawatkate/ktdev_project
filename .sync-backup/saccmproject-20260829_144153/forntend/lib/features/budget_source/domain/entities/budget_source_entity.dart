class BudgetSourceEntity {
  final String id;
  final String masterId;
  final String code;
  final String name;
  final String fiscalYear;
  final double budgetAmount;
  /// เงินงบคงเหลือยกมาจากปีก่อน (บวกกับวงเงินจัดสรรปีนี้)
  final double broughtForwardAmount;
  final double usedAmount;

  /// ยอดกันไว้ (เช็ค/ใบสั่งจ้าง ฯลฯ) — คอลัมน์ `reserved_amount` ใน `budget_source_budget`
  final double reservedAmount;
  final String budgetType;
  final String? description;

  /// ประเภทเงินตามระเบียบการคลัง (FK → money_group.id)
  /// ตัวอย่าง: เงินรายได้แผ่นดิน / เงินงบประมาณ / เงินนอกงบประมาณ /
  /// เงินภาษีหัก ณ ที่จ่าย / เงินประกันสัญญา
  final String? refMoneyGroup;

  /// ชื่อประเภทเงิน (join จาก money_group — ไม่บันทึกใน DB)
  final String? moneyGroupName;

  /// บัญชีธนาคารที่ผูกกับแหล่งเงินนี้ (FK → bank_account.id)
  /// ใช้เป็น default บัญชีรับ/จ่ายสำหรับทุกเอกสารที่อ้างแหล่งเงินนี้
  final String? refBankAccount;

  /// ชื่อบัญชีธนาคาร (join — ไม่บันทึกใน DB)
  final String? bankAccountName;

  const BudgetSourceEntity({
    required this.id,
    required this.masterId,
    required this.code,
    required this.name,
    required this.fiscalYear,
    required this.budgetAmount,
    this.broughtForwardAmount = 0,
    required this.usedAmount,
    this.reservedAmount = 0,
    required this.budgetType,
    this.description,
    this.refMoneyGroup,
    this.moneyGroupName,
    this.refBankAccount,
    this.bankAccountName,
  });

  double get totalAllocated => budgetAmount + broughtForwardAmount;

  /// ยอดที่ยังจ่ายได้จริง (หลังหักใช้ไปและยอดกันไว้)
  double get remaining => totalAllocated - usedAmount - reservedAmount;

  double get usedPercent =>
      totalAllocated > 0 ? (usedAmount / totalAllocated * 100) : 0;
}
