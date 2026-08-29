import 'package:flutter_test/flutter_test.dart';
import 'package:saccm/features/expense/domain/rules/expense_budget_source_rule.dart';

void main() {
  group('ExpenseBudgetSourceRule', () {
    const expenseTypes = <List<String>>[
      <String>['expense_type_05', '05 - ค่าครุภัณฑ์', ''],
      <String>['expense_type_01', '01 - ค่าตอบแทน', ''],
    ];

    const sources = <List<String>>[
      <String>['gov-1', 'GOV - เงินงบประมาณ'],
      <String>['nongov-1', 'NONGOV - เงินนอกงบประมาณ'],
      <String>['other-1', 'DONATION - เงินบริจาค'],
      <String>['bad-1', 'ไม่มีรหัส master'],
    ];

    test('keeps only GOV sources for gov-linked expense types', () {
      final result = ExpenseBudgetSourceRule.filterBudgetSources(
        allSources: sources,
        expenseTypeId: 'expense_type_05',
        expenseTypeRows: expenseTypes,
      );

      expect(result.map((e) => e.first), ['gov-1']);
    });

    test('keeps non-GOV sources for non-gov expense types', () {
      final result = ExpenseBudgetSourceRule.filterBudgetSources(
        allSources: sources,
        expenseTypeId: 'expense_type_01',
        expenseTypeRows: expenseTypes,
      );

      expect(result.map((e) => e.first), ['nongov-1', 'other-1']);
    });

    test('falls back to all sources when expense type cannot be resolved', () {
      final result = ExpenseBudgetSourceRule.filterBudgetSources(
        allSources: sources,
        expenseTypeId: 'unknown',
        expenseTypeRows: expenseTypes,
      );

      expect(result, sources);
    });
  });
}
