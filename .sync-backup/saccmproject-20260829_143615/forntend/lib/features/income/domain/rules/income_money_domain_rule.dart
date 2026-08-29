/// อนุมาน `money_domain` สำหรับหัวรายรับ — สอดคล้อง backend `income.service` + TEAM_RULES §11.1
class IncomeMoneyDomainRule {
  IncomeMoneyDomainRule._();

  static const Set<String> _govSubsidyCodes = {'01', '02', '03', '04', '05'};
  static const Set<String> _depositRegisterCodes = {'GUAR-01', 'WHT-01'};

  /// [incomeTypeRowId] เป็น `id` ใน SQLite (`income_type_OB-01`) หรือรหัสสั้น (`OB-01`)
  static String inferFromLookupId(String incomeTypeRowId) {
    var code = incomeTypeRowId.trim();
    if (code.startsWith('income_type_')) {
      code = code.substring('income_type_'.length);
    }
    return inferFromCode(code);
  }

  static String inferFromCode(String code) {
    final c = code.trim().toUpperCase();
    if (c.startsWith('OB-')) return 'off_budget';
    if (_govSubsidyCodes.contains(c)) return 'budget';
    if (c == 'TREASURY' || c.startsWith('TR-')) return 'treasury_income';
    return 'off_budget';
  }

  static bool isDepositRegisterCode(String code) {
    return _depositRegisterCodes.contains(code.trim().toUpperCase());
  }

  static bool isDepositRegisterLookupId(String incomeTypeRowId) {
    var code = incomeTypeRowId.trim();
    if (code.startsWith('income_type_')) {
      code = code.substring('income_type_'.length);
    }
    return isDepositRegisterCode(code);
  }
}
