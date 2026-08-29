import 'package:flutter/foundation.dart';

class ReportSyncStatusService extends ChangeNotifier {
  ReportSyncStatusService._();

  static final ReportSyncStatusService instance = ReportSyncStatusService._();

  int _activeSyncCount = 0;

  bool get isSyncing => _activeSyncCount > 0;

  void beginSync() {
    _activeSyncCount += 1;
    notifyListeners();
  }

  void endSync() {
    if (_activeSyncCount == 0) return;
    _activeSyncCount -= 1;
    notifyListeners();
  }

  void clear() {
    if (_activeSyncCount == 0) return;
    _activeSyncCount = 0;
    notifyListeners();
  }
}
