/// แมป "แหล่งเงิน + หมวด OB" → `cash_keeping_limit.fund_kind`
///
/// อ้างอิง: คู่มือการเงินหน้า 8-9 + canon `.cursor/rules/10-saccm-domain-core.mdc` §6
/// - `lunch`          → OB-09 (เงินอุดหนุนอาหารกลางวัน)
/// - `kosor`          → OB-11 (กสศ.)
/// - `school_revenue` → NONGOV ทั่วไป (เงินรายได้สถานศึกษา)
/// - `general`        → alias ของ school_revenue (backward-compat)
/// - null             → ไม่มี keep limit (เช่น GOV / งบประมาณแผ่นดิน)
abstract final class CashKeepingFundRule {
  CashKeepingFundRule._();

  static const String lunch = 'lunch';
  static const String kosor = 'kosor';
  static const String schoolRevenue = 'school_revenue';

  /// คืนชื่อ `fund_kind` ที่ใช้ค้น `cash_keeping_limit`
  /// - [budgetSourceMasterCode]: 'GOV' / 'NONGOV' (จาก label "GOV - ...")
  /// - [offBudgetCode]: 'OB-09' / 'OB-11' / ฯลฯ (อ่านจาก income_type.code ของ fundCategoryId)
  static String? resolveFundKind({
    required String? budgetSourceMasterCode,
    String? offBudgetCode,
  }) {
    final master = (budgetSourceMasterCode ?? '').toUpperCase();
    if (master == 'GOV') return null;

    final ob = (offBudgetCode ?? '').toUpperCase();
    if (ob == 'OB-09') return lunch;
    if (ob == 'OB-11') return kosor;
    if (master == 'NONGOV' || master.isEmpty) return schoolRevenue;
    return schoolRevenue;
  }

  /// คำอธิบาย fund_kind สำหรับแสดงผู้ใช้
  static String labelOf(String fundKind) {
    switch (fundKind) {
      case lunch:
        return 'เงินอุดหนุนอาหารกลางวัน';
      case kosor:
        return 'เงิน กสศ.';
      case schoolRevenue:
        return 'เงินรายได้สถานศึกษา';
      default:
        return fundKind;
    }
  }
}
