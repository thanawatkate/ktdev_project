import '../../domain/entities/lookup_item.dart';

class LookupItemModel extends LookupItem {
  const LookupItemModel({
    required super.id,
    required super.name,
    super.code,
    super.refFundCategory,
    super.refFundCategories,
    super.refBankAccount,
  });

  factory LookupItemModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['ref_fund_categories'] ??
        json['refFundCategories'] ??
        json['ref_income_types'] ??
        json['refIncomeTypes'];
    List<String>? refFundCategories;
    if (rawList is List) {
      refFundCategories = rawList
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final single = json['ref_fund_category']?.toString() ??
        json['refFundCategory']?.toString() ??
        json['ref_income_type']?.toString() ??
        json['refIncomeType']?.toString();
    return LookupItemModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString(),
      name: json['name']?.toString() ?? '',
      refFundCategory: (single != null && single.isNotEmpty)
          ? single
          : ((refFundCategories != null && refFundCategories.isNotEmpty)
              ? refFundCategories.first
              : null),
      refFundCategories: refFundCategories,
      refBankAccount: json['refbankaccount']?.toString() ??
          json['refBankAccount']?.toString(),
    );
  }
}
