import 'package:flutter/material.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/features/loan/data/repositories/repay_loan_repository_offline.dart';

class RepayLoanProvider extends ChangeNotifier {
  bool isLoading = false;
  String? error;
  bool _disposed = false;

  List<Map<String, dynamic>> rows = [];

  late final RepayLoanRepository _repository;

  RepayLoanProvider({RepayLoanRepository? repository}) {
    _repository =
        repository ?? ServiceLocator.instance.get<RepayLoanRepository>();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadRepayLoanList() async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final items = await _repository.getRepayLoanList();
      rows = items
          .map(
            (e) => {
              'id': e.id,
              'server_id': e.serverId,
              'docno': e.docno,
              'refLoan': e.refLoan,
              'amount': e.amount,
              'remark': e.remark,
              'created': e.created,
              'duedate': e.duedate,
              'synced': e.synced,
            },
          )
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<bool> saveRepayLoan({
    required String token,
    required String docno,
    required String refLoan,
    required String amount,
    required String remark,
    required String duedate,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.createRepayLoan(
        token: token,
        docno: docno,
        refLoan: refLoan,
        amount: amount,
        remark: remark,
        duedate: duedate,
      );
      await loadRepayLoanList();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<String?> fetchDocNo({
    required String tableName,
    required String docDate,
  }) async {
    try {
      return await _repository.getDocNo(tableName: tableName, docDate: docDate);
    } catch (e) {
      error = e.toString();
      _safeNotify();
      return null;
    }
  }

  Future<bool> updateRepayLoan({
    required String localId,
    required String token,
    required String docno,
    required String refLoan,
    required String amount,
    required String remark,
    required String duedate,
    required String created,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.updateRepayLoan(
        localId: localId,
        token: token,
        docno: docno,
        refLoan: refLoan,
        amount: amount,
        remark: remark,
        duedate: duedate,
        created: created,
      );
      await loadRepayLoanList();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<bool> deleteRepayLoan({
    required String localId,
    required String token,
    required String docno,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.deleteRepayLoan(
        localId: localId,
        token: token,
        docno: docno,
      );
      await loadRepayLoanList();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _safeNotify();
      return false;
    }
  }
}
