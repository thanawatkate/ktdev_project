import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/local_data_source/expense_req_local_data_source.dart';
import 'package:saccm/core/local_data_source/lookup_item_local_data_source.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/expense_req/data/repositories/expense_req_repository.dart';
import 'package:saccm/features/loan/data/repositories/loan_repository_offline.dart';

class ExpenseReqProvider extends ChangeNotifier {
  ExpenseReqProvider({
    ExpenseReqRepository? repository,
    BudgetSourceLocalDataSource? budgetSourceDs,
    IncomeTypeLocalDataSource? incomeTypeDs,
    LoanRepository? loanRepository,
  })  : _repository =
            repository ?? ServiceLocator.instance.get<ExpenseReqRepository>(),
        _budgetSourceDs = budgetSourceDs ?? BudgetSourceLocalDataSource(),
        _incomeTypeDs = incomeTypeDs ?? IncomeTypeLocalDataSource(),
        _loanRepository =
            loanRepository ?? ServiceLocator.instance.get<LoanRepository>();

  final ExpenseReqRepository _repository;
  final BudgetSourceLocalDataSource _budgetSourceDs;
  final IncomeTypeLocalDataSource _incomeTypeDs;
  final LoanRepository _loanRepository;

  bool isLoading = false;
  String? error;
  List<ExpenseReqModel> items = const [];
  List<List<String>> budgetSources = const [];
  List<List<String>> fundCategories = const [];
  String budgetSourceId = '';
  String fundCategoryId = '';

  void setBudgetSourceId(String? id) {
    budgetSourceId = id ?? '';
    _notify();
  }

  void setFundCategoryId(String? id) {
    fundCategoryId = id ?? '';
    _notify();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadList({String? approvalStatus}) async {
    isLoading = true;
    error = null;
    _notify();
    try {
      items = await _repository.listLocal(approvalStatus: approvalStatus);
    } catch (e) {
      error = toUserErrorMessage(e);
      items = const [];
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> loadLookups() async {
    try {
      await _budgetSourceDs.init();
      await _incomeTypeDs.init();
      final bs = await _budgetSourceDs.getAllBudgetSources();
      budgetSources =
          bs.map((b) => [b.id, '${b.code} — ${b.name}', b.name]).toList();
      final types = await _incomeTypeDs.getAllIncomeTypes();
      fundCategories = types
          .map((t) => [
                t.id,
                t.code.isNotEmpty ? '${t.code} — ${t.name}' : t.name,
                t.name,
              ])
          .toList();
      _notify();
    } catch (_) {}
  }

  Future<String?> fetchDocNo() async {
    final now = DateTime.now().toIso8601String().split('T').first;
    return _loanRepository.getDocNo(tableName: 'expense_req', docDate: now);
  }

  Future<String?> createDraft({
    required String token,
    required String docno,
    required String refMember,
    required String memberName,
    required String amount,
    required String detail,
  }) async {
    if (fundCategoryId.isEmpty) {
      error = TransactionUiText.expenseReqFundCategoryRequired;
      _notify();
      return null;
    }
    isLoading = true;
    error = null;
    _notify();
    try {
      String? bsName;
      for (final r in budgetSources) {
        if (r.isNotEmpty && r[0] == budgetSourceId) {
          bsName = r.length > 2 ? r[2] : r[1];
          break;
        }
      }
      final id = await _repository.createDraft(
        token: token,
        docno: docno,
        refMember: refMember,
        memberName: memberName,
        amount: amount,
        detail: detail,
        refBudgetSource: budgetSourceId.isEmpty ? null : budgetSourceId,
        budgetSourceName: bsName,
        subLines: [
          {
            'refincometype': fundCategoryId,
            'amount': amount,
            'remark': detail,
          },
        ],
      );
      return id;
    } catch (e) {
      error = toUserErrorMessage(e);
      return null;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<String?> upsertAutoDraft({
    String? localId,
    required String token,
    required String docno,
    required String refMember,
    required String memberName,
    required String amount,
    required String detail,
  }) async {
    if (fundCategoryId.isEmpty) {
      error = TransactionUiText.expenseReqFundCategoryRequired;
      return null;
    }
    try {
      String? bsName;
      for (final r in budgetSources) {
        if (r.isNotEmpty && r[0] == budgetSourceId) {
          bsName = r.length > 2 ? r[2] : r[1];
          break;
        }
      }
      final subLines = [
        {
          'refincometype': fundCategoryId,
          'amount': amount,
          'remark': detail,
        },
      ];
      if (localId != null && localId.trim().isNotEmpty) {
        await _repository.updateDraft(
          localId: localId,
          token: token,
          docno: docno,
          refMember: refMember,
          memberName: memberName,
          amount: amount,
          detail: detail,
          refBudgetSource: budgetSourceId.isEmpty ? null : budgetSourceId,
          budgetSourceName: bsName,
          subLines: subLines,
          silent: true,
        );
        error = null;
        return localId;
      }
      final id = await _repository.createDraft(
        token: token,
        docno: docno,
        refMember: refMember,
        memberName: memberName,
        amount: amount,
        detail: detail,
        refBudgetSource: budgetSourceId.isEmpty ? null : budgetSourceId,
        budgetSourceName: bsName,
        subLines: subLines,
        silent: true,
      );
      error = null;
      return id;
    } catch (e) {
      error = toUserErrorMessage(e);
      return null;
    }
  }

  Future<bool> submitForApproval({
    required String localId,
    required String token,
    String? note,
  }) async {
    isLoading = true;
    error = null;
    _notify();
    try {
      await _repository.submitForApproval(
        localId: localId,
        token: token,
        note: note,
      );
      return true;
    } catch (e) {
      error = toUserErrorMessage(e);
      return false;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<bool> deleteDraft({
    required String localId,
    required String token,
  }) async {
    isLoading = true;
    error = null;
    _notify();
    try {
      await _repository.deleteDraft(localId: localId, token: token);
      items = items.where((item) => item.id != localId).toList();
      return true;
    } catch (e) {
      error = toUserErrorMessage(e);
      return false;
    } finally {
      isLoading = false;
      _notify();
    }
  }
}
