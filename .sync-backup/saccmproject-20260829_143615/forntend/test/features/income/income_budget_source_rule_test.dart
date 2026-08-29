import 'package:flutter_test/flutter_test.dart';
import 'package:saccm/features/income/domain/rules/income_budget_source_rule.dart';

void main() {
  group('IncomeBudgetSourceRule', () {
    test('returns empty string when no source is available', () {
      final code = IncomeBudgetSourceRule.pickDefaultBudgetSourceCode(const []);
      expect(code, '');
    });

    test('returns empty string when first row is empty', () {
      final code = IncomeBudgetSourceRule.pickDefaultBudgetSourceCode(
        const [
          <String>[],
          <String>['B2', 'แหล่งเงินสำรอง'],
        ],
      );
      expect(code, '');
    });

    test('returns empty string when more than one source is available', () {
      final code = IncomeBudgetSourceRule.pickDefaultBudgetSourceCode(
        const [
          <String>['B1', 'งบประมาณแผ่นดิน'],
          <String>['B2', 'เงินนอกงบประมาณ'],
        ],
      );
      expect(code, '');
    });

    test('returns the only source id for deterministic default', () {
      final code = IncomeBudgetSourceRule.pickDefaultBudgetSourceCode(
        const [
          <String>['B1', 'งบประมาณแผ่นดิน'],
        ],
      );
      expect(code, 'B1');
    });
  });
}
