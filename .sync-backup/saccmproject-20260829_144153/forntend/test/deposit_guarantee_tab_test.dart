import 'package:flutter_test/flutter_test.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

void main() {
  test('deposit register UI strings are defined', () {
    expect(TransactionUiText.registerDepositSubTabAll, isNotEmpty);
    expect(TransactionUiText.registerDepositEditTitle, isNotEmpty);
    expect(TransactionUiText.formsCardDepositRegisterTitle, isNotEmpty);
  });
}
