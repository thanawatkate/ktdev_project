import 'package:saccm/core/utils/sqlite_money_field.dart';
import 'package:saccm/features/income/domain/entities/income_entity.dart';

class IncomeModel extends IncomeEntity {
  final bool synced;

  const IncomeModel({
    required super.id,
    required super.docno,
    required super.docdate,
    required super.detail,
    required super.amount,
    required super.remark,
    super.bankReference,
    required super.created,
    super.refBudgetSource,
    super.budgetSourceName,
    super.refIncomeType,
    super.refParty,
    super.partyName,
    super.refMoneyType,
    super.refBankAccount,
    super.docStatus,
    super.moneyDomain,
    super.approvedBy,
    super.approvedAt,
    super.postedAt,
    super.changeReason,
    this.synced = true,
  });

  factory IncomeModel.fromJson(Map<String, dynamic> json) {
    return IncomeModel(
      id: json['id']?.toString() ?? '',
      docno: json['docno']?.toString() ?? '',
      docdate: json['docdate']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      amount: sqliteMoneyToString(json['amount']),
      remark: json['remark']?.toString() ?? '',
      bankReference: json['bank_reference']?.toString() ??
          json['bankReference']?.toString(),
      created: json['created']?.toString() ?? '',
      refBudgetSource: json['refBudgetSource']?.toString(),
      budgetSourceName: json['budgetSourceName']?.toString(),
      refIncomeType: json['refIncomeType']?.toString() ??
          json['refincometype']?.toString(),
      refParty: json['refParty']?.toString(),
      partyName: json['partyName']?.toString(),
      refMoneyType: json['refMoneyType']?.toString(),
      refBankAccount: json['refBankAccount']?.toString() ??
          json['refbankaccount']?.toString(),
      docStatus:
          json['doc_status']?.toString() ?? json['docStatus']?.toString(),
      moneyDomain:
          json['money_domain']?.toString() ?? json['moneyDomain']?.toString(),
      approvedBy:
          json['approved_by']?.toString() ?? json['approvedBy']?.toString(),
      approvedAt:
          json['approved_at']?.toString() ?? json['approvedAt']?.toString(),
      postedAt: json['posted_at']?.toString() ?? json['postedAt']?.toString(),
      changeReason:
          json['change_reason']?.toString() ?? json['changeReason']?.toString(),
      synced: (json['synced'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'docno': docno,
      'docdate': docdate,
      'detail': detail,
      'amount': amount,
      'remark': remark,
      'bank_reference': bankReference,
      'created': created,
      'refBudgetSource': refBudgetSource,
      'budgetSourceName': budgetSourceName,
      'refIncomeType': refIncomeType,
      'refParty': refParty,
      'partyName': partyName,
      'refMoneyType': refMoneyType,
      'refBankAccount': refBankAccount,
      'doc_status': docStatus,
      'money_domain': moneyDomain,
      'approved_by': approvedBy,
      'approved_at': approvedAt,
      'posted_at': postedAt,
      'change_reason': changeReason,
      'synced': synced ? 1 : 0,
    };
  }
}
