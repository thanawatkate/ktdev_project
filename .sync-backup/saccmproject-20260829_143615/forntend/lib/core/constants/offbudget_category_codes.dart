/// รหัสหมวดเงินนอกงบประมาณ (OB-XX) ที่เป็น **รายรับเท่านั้น** — ไม่ควรใช้เป็นปลายทางรายจ่าย
///
/// อ้างอิง: `.cursor/rules/10-saccm-domain-core.mdc` §2 + คู่มือการเงินหน้า 6, 9
/// - OB-10: เงินดอกผลกองทุนโครงการอาหารกลางวัน (รายรับจากดอกเบี้ย)
/// - OB-12: ดอกเบี้ยบัญชีเงินอุดหนุนอื่น (รายได้เบ็ดเตล็ด)
/// - OB-13: ดอกเบี้ยบัญชีโครงการอาหารกลางวัน (ดอกผลที่นำส่งคลัง)
///
/// ใช้กรอง dropdown หมวดทะเบียนคุมในหน้าบันทึกรายจ่าย เพื่อกันไม่ให้ผู้ใช้
/// บันทึกรายจ่ายเข้าหมวดที่ตามคู่มือเป็นรายรับเท่านั้น
abstract final class OffBudgetCategoryCodes {
  OffBudgetCategoryCodes._();

  /// รหัส OB ที่กำหนดเป็น "รายรับเท่านั้น" (ไม่อนุญาตให้ใช้ใน expense_sub.refFundCategory)
  static const Set<String> incomeOnly = <String>{
    'OB-10',
    'OB-12',
    'OB-13',
  };

  static bool isIncomeOnly(String? code) {
    if (code == null || code.isEmpty) return false;
    return incomeOnly.contains(code.toUpperCase());
  }
}
