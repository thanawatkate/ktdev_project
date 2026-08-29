class IncomeBudgetSourceRule {
  const IncomeBudgetSourceRule._();

  /// เลือกแหล่งเงินค่าเริ่มต้นจากรายการที่กรองตามหมวดรายรับแล้ว
  /// เลือกอัตโนมัติเฉพาะเมื่อมีตัวเลือกเดียว เพื่อลดความเสี่ยงบันทึกผิดแหล่งเงิน
  static String pickDefaultBudgetSourceCode(List<List<String>> sources) {
    if (sources.length != 1) return '';
    final first = sources.first;
    if (first.isEmpty) return '';
    return first[0];
  }
}
