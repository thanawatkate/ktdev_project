import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/constants/gov_expense_type_codes.dart';
import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';

String expenseTypeBudgetDropdownLabel(BudgetSourceModel b) {
  final code = b.code.trim();
  final masterLabel =
      code.isNotEmpty ? '[$code] ${b.name.trim()}' : b.name.trim();
  if (masterLabel.isEmpty) return b.id;
  final fy = b.fiscalYear.trim();
  if (fy.isEmpty) {
    return '${TransactionUiText.expenseTypeDefaultBudgetLabel}: $masterLabel';
  }
  return TransactionUiText.expenseTypeDefaultBudgetSummary(
    masterLabel: masterLabel,
    fiscalYear: fy,
  );
}

/// สอดคล้อง `backend/migrations/20260517000001_alter_expensetype_add_refdefaultbudgetsource.js`
/// และ `AppDatabase._seedDefaultCategoryBudgetSourceLinks`
String? defaultBudgetSourceIdForExpenseTypeCode(
  String code,
  List<BudgetSourceModel> rows,
) {
  if (rows.isEmpty) return null;
  final c = code.trim();
  final wantGov = c.isNotEmpty &&
      GovExpenseTypeCodes.linkedToGovMaster.contains(c);
  final wantMaster = wantGov ? 'GOV' : 'NONGOV';
  final fy = (DateTime.now().year + 543).toString();
  BudgetSourceModel? fyMatch;
  BudgetSourceModel? anyMatch;
  for (final b in rows) {
    if (b.code != wantMaster) continue;
    if (b.fiscalYear == fy) {
      fyMatch = b;
      break;
    }
    anyMatch ??= b;
  }
  return (fyMatch ?? anyMatch)?.id;
}

/// สรุปข้อความจากแถว join (`refDefaultBudgetSource` + `budget_source_*`)
String? expenseTypeDefaultBudgetSummaryFromJoinedRow(Map<String, Object?> r) {
  final ref = r['refDefaultBudgetSource']?.toString().trim() ?? '';
  if (ref.isEmpty) return null;
  final fy = r['default_budget_fiscal_year']?.toString().trim() ?? '';
  final mName = r['default_master_name']?.toString().trim() ?? '';
  final mCode = r['default_master_code']?.toString().trim() ?? '';
  final masterLabel = mName.isNotEmpty
      ? (mCode.isNotEmpty ? '[$mCode] $mName' : mName)
      : (mCode.isNotEmpty ? mCode : ref);
  if (fy.isEmpty) {
    return '${TransactionUiText.expenseTypeDefaultBudgetLabel}: $masterLabel';
  }
  return TransactionUiText.expenseTypeDefaultBudgetSummary(
    masterLabel: masterLabel,
    fiscalYear: fy,
  );
}

