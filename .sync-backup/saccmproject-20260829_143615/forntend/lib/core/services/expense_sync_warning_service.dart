import 'package:flutter/foundation.dart';

class ExpenseSyncWarningService extends ChangeNotifier {
  ExpenseSyncWarningService._();

  static final ExpenseSyncWarningService instance =
      ExpenseSyncWarningService._();

  String? _message;

  String? get message => _message;

  void setWarning(String? message) {
    final next = (message == null || message.trim().isEmpty) ? null : message;
    if (_message == next) return;
    _message = next;
    notifyListeners();
  }

  void clear() => setWarning(null);
}
