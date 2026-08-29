import '../../domain/entities/budget_source_entity.dart';
import '../../../../constants/transaction_ui_text.dart';

class BudgetSourceModel extends BudgetSourceEntity {
  const BudgetSourceModel({
    required super.id,
    required super.masterId,
    required super.code,
    required super.name,
    required super.fiscalYear,
    required super.budgetAmount,
    super.broughtForwardAmount = 0,
    required super.usedAmount,
    super.reservedAmount = 0,
    required super.budgetType,
    super.description,
    super.refMoneyGroup,
    super.moneyGroupName,
    super.refBankAccount,
    super.bankAccountName,
  });

  factory BudgetSourceModel.fromJson(Map<String, dynamic> json) {
    final rawMg = json['refmoneygroup'] ??
        json['ref_money_group'] ??
        json['refMoneyGroup'];
    final rawBa = json['refbankaccount'] ??
        json['ref_bank_account'] ??
        json['refBankAccount'];
    return BudgetSourceModel(
      id: json['id']?.toString() ?? '',
      masterId: json['master_id']?.toString() ??
          json['masterId']?.toString() ??
          json['code']?.toString() ??
          '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      fiscalYear: json['fiscal_year']?.toString() ?? '',
      budgetAmount: double.tryParse(json['budget_amount']?.toString() ?? '0') ?? 0,
      broughtForwardAmount:
          double.tryParse(json['brought_forward_amount']?.toString() ?? '0') ?? 0,
      usedAmount: double.tryParse(json['used_amount']?.toString() ?? '0') ?? 0,
      reservedAmount:
          double.tryParse(json['reserved_amount']?.toString() ?? '0') ?? 0,
      budgetType:
          json['budget_type']?.toString() ?? TransactionUiText.budgetTypeGov,
      description: json['description']?.toString(),
      refMoneyGroup: (rawMg == null ||
              rawMg.toString().isEmpty ||
              rawMg.toString() == '0')
          ? null
          : rawMg.toString(),
      moneyGroupName: json['money_group_name']?.toString() ??
          json['moneyGroupName']?.toString(),
      refBankAccount: (rawBa == null ||
              rawBa.toString().isEmpty ||
              rawBa.toString() == '0')
          ? null
          : rawBa.toString(),
      bankAccountName: json['bank_account_name']?.toString() ??
          json['bankAccountName']?.toString(),
    );
  }

  BudgetSourceModel copyWith({
    String? id,
    String? masterId,
    String? code,
    String? name,
    String? fiscalYear,
    double? budgetAmount,
    double? broughtForwardAmount,
    double? usedAmount,
    double? reservedAmount,
    String? budgetType,
    String? description,
    String? refMoneyGroup,
    String? moneyGroupName,
    String? refBankAccount,
    String? bankAccountName,
  }) {
    return BudgetSourceModel(
      id: id ?? this.id,
      masterId: masterId ?? this.masterId,
      code: code ?? this.code,
      name: name ?? this.name,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      broughtForwardAmount: broughtForwardAmount ?? this.broughtForwardAmount,
      usedAmount: usedAmount ?? this.usedAmount,
      reservedAmount: reservedAmount ?? this.reservedAmount,
      budgetType: budgetType ?? this.budgetType,
      description: description ?? this.description,
      refMoneyGroup: refMoneyGroup ?? this.refMoneyGroup,
      moneyGroupName: moneyGroupName ?? this.moneyGroupName,
      refBankAccount: refBankAccount ?? this.refBankAccount,
      bankAccountName: bankAccountName ?? this.bankAccountName,
    );
  }
}
