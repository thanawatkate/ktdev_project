import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:saccm/core/utils/sqlite_money_field.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseReqModel {
  const ExpenseReqModel({
    required this.id,
    this.serverId,
    required this.docno,
    this.docdate,
    required this.amount,
    this.detail,
    this.remark,
    required this.refMember,
    this.refBudgetSource,
    this.approvalStatus = 'draft',
    this.rejectReason,
    this.memberName,
    this.budgetSourceName,
    required this.created,
    this.synced = false,
  });

  final String id;
  final String? serverId;
  final String docno;
  final String? docdate;
  final String amount;
  final String? detail;
  final String? remark;
  final String refMember;
  final String? refBudgetSource;
  final String approvalStatus;
  final String? rejectReason;
  final String? memberName;
  final String? budgetSourceName;
  final String created;
  final bool synced;

  String get effectiveServerId =>
      serverId?.trim().isNotEmpty == true ? serverId! : id;

  String get memberLabel =>
      (memberName?.trim().isNotEmpty == true) ? memberName! : refMember;
}

class ExpenseReqSubModel {
  const ExpenseReqSubModel({
    required this.id,
    required this.refExpenseReq,
    required this.refFundCategory,
    required this.amount,
    this.remark,
  });

  final String id;
  final String refExpenseReq;
  final String refFundCategory;
  final String amount;
  final String? remark;
}

class ExpenseReqLocalDataSource extends BaseLocalDataSource {
  Future<List<ExpenseReqModel>> getAll({String? approvalStatus}) async {
    await ensureInitialized();
    final rows = await db.query(
      'expense_req',
      where: approvalStatus != null ? 'approval_status = ?' : null,
      whereArgs: approvalStatus != null ? [approvalStatus] : null,
      orderBy: 'created DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<ExpenseReqModel>> getApprovedReadyForExpenseEntry() async {
    await ensureInitialized();
    final hasRecordedColumn = await _tableHasExpenseRecordedColumn();
    final where = hasRecordedColumn
        ? "approval_status = ? AND COALESCE(expense_recorded, 0) = 0"
        : 'approval_status = ?';
    final rows = await db.query(
      'expense_req',
      where: where,
      whereArgs: const ['approved'],
      orderBy: 'created DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<ExpenseReqModel?> getByServerId(String serverId) async {
    await ensureInitialized();
    final rows = await db.query(
      'expense_req',
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<ExpenseReqModel?> getById(String id) async {
    await ensureInitialized();
    final rows = await db.query(
      'expense_req',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> saveHeader(ExpenseReqModel model, {bool synced = false}) async {
    await ensureInitialized();
    await db.insert(
      'expense_req',
      {
        'id': model.id,
        'server_id': model.serverId,
        'docno': model.docno,
        'docdate': model.docdate,
        'amount': sqliteMoneyToDouble(model.amount),
        'detail': model.detail,
        'remark': model.remark,
        'refMember': model.refMember,
        'refBudgetSource': model.refBudgetSource,
        'approval_status': model.approvalStatus,
        'reject_reason': model.rejectReason,
        'member_name': model.memberName,
        'budget_source_name': model.budgetSourceName,
        'created': model.created,
        'updated': DateTime.now().toIso8601String(),
        'synced': synced ? 1 : 0,
        'lastModified': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateApprovalStatus(
    String id, {
    required String status,
    String? rejectReason,
    String? serverId,
    bool? synced,
  }) async {
    await ensureInitialized();
    final patch = <String, Object?>{
      'approval_status': status,
      'reject_reason': rejectReason,
      'updated': DateTime.now().toIso8601String(),
      'lastModified': DateTime.now().toIso8601String(),
    };
    if (serverId != null) patch['server_id'] = serverId;
    if (synced != null) patch['synced'] = synced ? 1 : 0;
    await db.update('expense_req', patch, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markExpenseRecorded(String id) async {
    await ensureInitialized();
    if (!await _tableHasExpenseRecordedColumn()) return;
    await db.update(
      'expense_req',
      {
        'expense_recorded': 1,
        'updated': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ? OR server_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<bool> isExpenseRecorded(String id) async {
    await ensureInitialized();
    if (!await _tableHasExpenseRecordedColumn()) return false;
    final rows = await db.query(
      'expense_req',
      columns: ['expense_recorded'],
      where: 'id = ? OR server_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['expense_recorded'] as int? ?? 0) == 1;
  }

  Future<bool> _tableHasExpenseRecordedColumn() async {
    final rows = await db.rawQuery('PRAGMA table_info(expense_req)');
    for (final r in rows) {
      if (r['name']?.toString() == 'expense_recorded') return true;
    }
    return false;
  }

  Future<void> applyServerId(String localId, String serverId) async {
    await ensureInitialized();
    await db.update(
      'expense_req',
      {
        'server_id': serverId,
        'synced': 1,
        'updated': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> saveSub(ExpenseReqSubModel sub, {bool synced = false}) async {
    await ensureInitialized();
    await db.insert(
      'expense_req_sub',
      {
        'id': sub.id,
        'refExpenseReq': sub.refExpenseReq,
        'refFundCategory': sub.refFundCategory,
        'amount': sqliteMoneyToDouble(sub.amount),
        'remark': sub.remark,
        'created': DateTime.now().toIso8601String(),
        'updated': DateTime.now().toIso8601String(),
        'synced': synced ? 1 : 0,
        'lastModified': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceSubs(
    String refExpenseReq,
    List<ExpenseReqSubModel> subs, {
    bool synced = false,
  }) async {
    await ensureInitialized();
    await db.transaction((txn) async {
      await txn.delete(
        'expense_req_sub',
        where: 'refExpenseReq = ?',
        whereArgs: [refExpenseReq],
      );
      for (final sub in subs) {
        await txn.insert(
          'expense_req_sub',
          {
            'id': sub.id,
            'refExpenseReq': refExpenseReq,
            'refFundCategory': sub.refFundCategory,
            'amount': sqliteMoneyToDouble(sub.amount),
            'remark': sub.remark,
            'created': DateTime.now().toIso8601String(),
            'updated': DateTime.now().toIso8601String(),
            'synced': synced ? 1 : 0,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteHeader(String id) async {
    await ensureInitialized();
    await db.delete('expense_req', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExpenseReqSubModel>> getSubs(String refExpenseReq) async {
    await ensureInitialized();
    final rows = await db.query(
      'expense_req_sub',
      where: 'refExpenseReq = ?',
      whereArgs: [refExpenseReq],
    );
    return rows
        .map(
          (r) => ExpenseReqSubModel(
            id: r['id']?.toString() ?? '',
            refExpenseReq: r['refExpenseReq']?.toString() ?? '',
            refFundCategory: r['refFundCategory']?.toString() ?? '',
            amount: (r['amount'] ?? 0).toString(),
            remark: r['remark']?.toString(),
          ),
        )
        .toList();
  }

  ExpenseReqModel _fromRow(Map<String, Object?> r) {
    return ExpenseReqModel(
      id: r['id']?.toString() ?? '',
      serverId: r['server_id']?.toString(),
      docno: r['docno']?.toString() ?? '',
      docdate: r['docdate']?.toString(),
      amount: (r['amount'] ?? 0).toString(),
      detail: r['detail']?.toString(),
      remark: r['remark']?.toString(),
      refMember: r['refMember']?.toString() ?? '',
      refBudgetSource: r['refBudgetSource']?.toString(),
      approvalStatus: r['approval_status']?.toString() ?? 'draft',
      rejectReason: r['reject_reason']?.toString(),
      memberName: r['member_name']?.toString(),
      budgetSourceName: r['budget_source_name']?.toString(),
      created: r['created']?.toString() ?? '',
      synced: (r['synced'] as int? ?? 0) == 1,
    );
  }
}
