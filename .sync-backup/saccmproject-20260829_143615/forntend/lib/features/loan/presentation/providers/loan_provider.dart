import 'package:flutter/material.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/features/loan/data/repositories/loan_repository_offline.dart';

class LoanProvider extends ChangeNotifier {
  bool isLoading = false;
  String? error;
  bool _disposed = false;

  List<Map<String, dynamic>> rows = [];

  late final LoanRepository _repository;

  LoanProvider({LoanRepository? repository}) {
    _repository = repository ?? ServiceLocator.instance.get<LoanRepository>();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadLoanList() async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      final items = await _repository.getLoanList();
      rows = items
          .map(
            (e) => {
              'id': e.id,
              'server_id': e.serverId,
              'docno': e.docno,
              'borrower': e.borrowerLabel,
              'ref_member': e.refMember,
              'amount': e.amount,
              'duedate': e.duedate,
              'opening_outstanding': e.openingOutstanding,
              'remark': e.remark,
              'created': e.created,
              'outstanding': e.outstanding,
              'is_overdue': e.isOverdue,
              'loandate': e.loandate,
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

  Future<bool> saveLoan({
    required String token,
    required String docno,
    required String borrower,
    double openingOutstanding = 0,
    required String remark,
    required String loandate,
    required String duedate,
    List<LoanSubLineInput> subLines = const [],
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.createLoan(
        token: token,
        docno: docno,
        borrower: borrower,
        openingOutstanding: openingOutstanding,
        remark: remark,
        loandate: loandate,
        duedate: duedate,
        subLines: subLines,
      );
      await loadLoanList();
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

  Future<bool> updateLoan({
    required String localId,
    required String token,
    required String docno,
    required String borrower,
    double openingOutstanding = 0,
    required String remark,
    required String loandate,
    required String duedate,
    required String created,
    List<LoanSubLineInput> subLines = const [],
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.updateLoan(
        localId: localId,
        token: token,
        docno: docno,
        borrower: borrower,
        openingOutstanding: openingOutstanding,
        remark: remark,
        loandate: loandate,
        duedate: duedate,
        created: created,
        subLines: subLines,
      );
      await loadLoanList();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<bool> deleteLoan({
    required String localId,
    required String token,
    required String docno,
  }) async {
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.deleteLoan(
        localId: localId,
        token: token,
        docno: docno,
      );
      await loadLoanList();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<Map<String, dynamic>?> findActiveOutstandingLoanByBorrower(
    String borrower, {
    String? excludeLoanId,
  }) {
    return _repository.findActiveOutstandingLoanByBorrower(
      borrower,
      excludeLoanId: excludeLoanId,
    );
  }
}
