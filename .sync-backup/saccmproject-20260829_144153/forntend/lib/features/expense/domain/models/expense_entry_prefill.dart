import 'package:saccm/constants/transaction_ui_text.dart';

/// ข้อมูลเติมลงฟอร์มบันทึกเบิกจริง หลังอนุมัติใบขอเบิก
class ExpenseEntryPrefill {
  const ExpenseEntryPrefill({
    required this.expenseReqId,
    required this.expenseReqDocNo,
    required this.amount,
    required this.detail,
    required this.payToName,
    this.expenseReqServerId,
    this.budgetSourceRowId,
    this.fundCategoryId,
    this.remark,
  });

  final String expenseReqId;
  final String? expenseReqServerId;
  final String expenseReqDocNo;
  final String amount;
  final String detail;
  final String payToName;
  final String? budgetSourceRowId;
  final String? fundCategoryId;
  final String? remark;

  String get referenceNote =>
      '${TransactionUiText.expenseFromApprovedReqPrefix}$expenseReqDocNo';
}
