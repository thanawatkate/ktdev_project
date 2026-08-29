/// Generic entity for dropdown/lookup data with id and name fields.
class LookupItem {
  final String id;
  final String name;
  final String? code;
  final String? refFundCategory;
  final List<String>? refFundCategories;

  /// FK ไป `bank_account` ที่ master แหล่งเงิน (SQLite `budget_source_master.refBankAccount`)
  final String? refBankAccount;

  const LookupItem({
    required this.id,
    required this.name,
    this.code,
    this.refFundCategory,
    this.refFundCategories,
    this.refBankAccount,
  });

  // Backward compatibility for call sites that still use legacy names.
  String? get refIncomeType => refFundCategory;
  List<String>? get refIncomeTypes => refFundCategories;
}
