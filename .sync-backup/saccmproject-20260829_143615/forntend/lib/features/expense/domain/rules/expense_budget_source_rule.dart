import 'package:saccm/core/constants/gov_expense_type_codes.dart';

/// กฎผูกประเภทรายจ่ายกับแหล่งเงิน (งบแผ่นดิน vs นอกงบประมาณ)
/// สะท้อน logic ใน `AppDatabase._seedDefaultCategoryBudgetSourceLinks`
class ExpenseBudgetSourceRule {
  const ExpenseBudgetSourceRule._();

  /// แปลง `expense_type.id` (เช่น expense_type_01) → code (01)
  static String? expenseTypeCodeFromId(
    String expenseTypeId,
    List<List<String>> expenseTypeRows,
  ) {
    if (expenseTypeId.startsWith('expense_type_')) {
      return expenseTypeId.substring('expense_type_'.length);
    }
    for (final row in expenseTypeRows) {
      if (row.isEmpty || row[0] != expenseTypeId) continue;
      if (row.length > 1) {
        final label = row[1];
        final i = label.indexOf(' - ');
        if (i > 0) return label.substring(0, i).trim();
      }
    }
    return null;
  }

  static bool usesGovBudgetMaster(String? expenseTypeCode) {
    if (expenseTypeCode == null || expenseTypeCode.isEmpty) return false;
    return GovExpenseTypeCodes.linkedToGovMaster.contains(expenseTypeCode);
  }

  /// แยก master code จาก label แถวแหล่งเงิน เช่น "GOV - ..." / "NONGOV - ..."
  static String? masterCodeFromBudgetRowLabel(String label) {
    final i = label.indexOf(' - ');
    if (i <= 0) return null;
    return label.substring(0, i).trim().toUpperCase();
  }

  /// กรองแหล่งเงินที่แสดงใน dropdown ตามประเภทรายจ่ายที่เลือก
  /// แถวรูปแบบ `[budgetId, label]` โดย label ขึ้นต้นด้วยรหัส master (GOV / NONGOV ฯลฯ)
  static List<List<String>> filterBudgetSources({
    required List<List<String>> allSources,
    required String expenseTypeId,
    required List<List<String>> expenseTypeRows,
  }) {
    if (allSources.isEmpty) return const [];
    final code = expenseTypeCodeFromId(expenseTypeId, expenseTypeRows);
    if (code == null || code.isEmpty) return List<List<String>>.from(allSources);

    final wantGov = usesGovBudgetMaster(code);
    final out = <List<String>>[];
    for (final row in allSources) {
      if (row.length < 2) continue;
      final mc = masterCodeFromBudgetRowLabel(row[1]);
      if (mc == null) continue;
      if (wantGov) {
        if (mc == 'GOV') out.add(row);
      } else {
        if (mc != 'GOV') out.add(row);
      }
    }
    return out;
  }
}
