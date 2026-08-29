import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/local_data_source/expense_req_local_data_source.dart';
import 'package:saccm/features/expense/domain/models/expense_entry_prefill.dart';

/// แปลงรายการอนุมัติ (expensereq) → ค่าเริ่มต้นฟอร์มบันทึกเบิกจริง
class ExpenseEntryPrefillResolver {
  ExpenseEntryPrefillResolver({
    ExpenseReqLocalDataSource? expenseReqLocal,
    BudgetSourceLocalDataSource? budgetLocal,
  })  : _reqLocal = expenseReqLocal ??
            ServiceLocator.instance.get<ExpenseReqLocalDataSource>(),
        _budgetLocal = budgetLocal ?? BudgetSourceLocalDataSource();

  final ExpenseReqLocalDataSource _reqLocal;
  final BudgetSourceLocalDataSource _budgetLocal;

  Future<ExpenseEntryPrefill?> resolve(
      Map<String, dynamic> approvalItem) async {
    final serverId = approvalItem['id']?.toString() ?? '';
    if (serverId.isEmpty) return null;

    await _reqLocal.ensureInitialized();
    await _budgetLocal.init();

    ExpenseReqModel? local = await _reqLocal.getByServerId(serverId);
    local ??= await _reqLocal.getById(serverId);

    final docno = approvalItem['docno']?.toString() ?? local?.docno ?? serverId;
    final amount = (approvalItem['amount'] ?? local?.amount ?? '0').toString();
    final detail = (approvalItem['detail'] ??
            approvalItem['remark'] ??
            local?.detail ??
            local?.remark ??
            '')
        .toString()
        .trim();
    final payTo = (approvalItem['member_name'] ?? local?.memberName ?? '')
        .toString()
        .trim();

    final rawBudget = (approvalItem['refbudgetsource'] ??
            approvalItem['refBudgetSource'] ??
            local?.refBudgetSource)
        ?.toString();
    final budgetRowId = await _resolveBudgetRowId(rawBudget);

    String? fundCategoryId;
    if (local != null) {
      final subs = await _reqLocal.getSubs(local.id);
      if (subs.isNotEmpty) {
        fundCategoryId = subs.first.refFundCategory;
      }
    }

    return ExpenseEntryPrefill(
      expenseReqId: local?.id ?? serverId,
      expenseReqServerId: local?.serverId?.trim().isNotEmpty == true
          ? local!.serverId
          : serverId,
      expenseReqDocNo: docno,
      amount: amount,
      detail: detail.isNotEmpty ? detail : docno,
      payToName: payTo,
      budgetSourceRowId: budgetRowId,
      fundCategoryId:
          fundCategoryId?.isNotEmpty == true ? fundCategoryId : null,
      remark: approvalItem['reject_reason'] == null
          ? (local?.remark ?? detail)
          : null,
    );
  }

  Future<String?> _resolveBudgetRowId(String? raw) async {
    final id = raw?.trim();
    if (id == null || id.isEmpty) return null;
    final rows = await _budgetLocal.db.query(
      'budget_source_budget',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id']?.toString();
    final all = await _budgetLocal.getAllBudgetSources();
    for (final b in all) {
      if (b.id == id || b.masterId == id) return b.id;
    }
    return id;
  }
}
