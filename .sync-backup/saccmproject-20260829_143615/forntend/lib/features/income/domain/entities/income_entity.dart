class IncomeEntity {
  final String id;
  final String docno;
  final String docdate;
  final String detail;
  final String amount;
  final String remark;
  final String? bankReference;
  final String created;
  final String? refBudgetSource;
  final String? budgetSourceName;
  final String? refIncomeType;
  final String? refParty;
  final String? partyName;
  final String? refMoneyType;
  final String? refBankAccount;
  final String? docStatus;
  final String? moneyDomain;
  final String? approvedBy;
  final String? approvedAt;
  final String? postedAt;
  final String? changeReason;

  const IncomeEntity({
    required this.id,
    required this.docno,
    required this.docdate,
    required this.detail,
    required this.amount,
    required this.remark,
    this.bankReference,
    required this.created,
    this.refBudgetSource,
    this.budgetSourceName,
    this.refIncomeType,
    this.refParty,
    this.partyName,
    this.refMoneyType,
    this.refBankAccount,
    this.docStatus,
    this.moneyDomain,
    this.approvedBy,
    this.approvedAt,
    this.postedAt,
    this.changeReason,
  });
}
