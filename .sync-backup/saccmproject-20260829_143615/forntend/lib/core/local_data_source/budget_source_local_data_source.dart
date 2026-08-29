import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';
import 'package:sqflite/sqflite.dart';

import 'base_local_data_source.dart';

/// ยอดงบจากแถว `budget_source_budget` — ใช้คำนวณยอดคงเหลือที่ใช้จ่ายได้ก่อนบันทึกรายจ่าย
class BudgetBalanceSnapshot {
  const BudgetBalanceSnapshot({
    required this.budgetAmount,
    required this.broughtForwardAmount,
    required this.usedAmount,
    required this.reservedAmount,
  });

  final double budgetAmount;
  final double broughtForwardAmount;
  final double usedAmount;
  final double reservedAmount;

  double get totalCap => budgetAmount + broughtForwardAmount;

  /// ยอดที่ยังจ่ายได้จริง (หลังหักยอดใช้ไปและยอดกันเงิน)
  double get available => totalCap - usedAmount - reservedAmount;
}

/// ตัวเลือก "ประเภทเงิน" สำหรับ dropdown (อ่านจาก money_group)
class MoneyGroupOption {
  final String id;
  final String name;
  const MoneyGroupOption({required this.id, required this.name});
}

class BudgetSourceLocalDataSource extends BaseLocalDataSource {
  /// อ่านรายการประเภทเงิน (เฉพาะที่ใช้งาน) เรียงตาม sort
  Future<List<MoneyGroupOption>> getAllMoneyGroups(
      {bool activeOnly = true}) async {
    final where = activeOnly ? "use = 'Y'" : null;
    final rows = await db.query(
      'money_group',
      columns: ['id', 'name'],
      where: where,
      orderBy: 'sort ASC, name ASC',
    );
    return rows
        .map((r) => MoneyGroupOption(
              id: r['id']?.toString() ?? '',
              name: r['name']?.toString() ?? '',
            ))
        .toList();
  }

  Future<void> saveBudgetSource(BudgetSourceModel item,
      {bool synced = true}) async {
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert(
        'budget_source_master',
        {
          'id': item.masterId,
          'code': item.code,
          'name': item.name,
          'budget_type': item.budgetType,
          'refmoneygroup': item.refMoneyGroup,
          'refBankAccount': item.refBankAccount,
          'description': item.description,
          'synced': synced ? 1 : 0,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'budget_source_budget',
        {
          'id': item.id,
          'refBudgetSourceMaster': item.masterId,
          'fiscal_year': item.fiscalYear,
          'budget_amount': item.budgetAmount,
          'brought_forward_amount': item.broughtForwardAmount,
          'used_amount': item.usedAmount,
          'reserved_amount': item.reservedAmount,
          'synced': synced ? 1 : 0,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> saveBudgetSources(List<BudgetSourceModel> items) async {
    final deleting = await pendingDeleteProtectionFor('budget_source_delete_');
    final unsyncedMasters = await db.query(
      'budget_source_master',
      columns: ['id'],
      where: 'synced = 0',
    );
    final unsyncedBudgets = await db.query(
      'budget_source_budget',
      columns: ['id'],
      where: 'synced = 0',
    );
    final protectedMasterIds = unsyncedMasters
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final protectedBudgetIds = unsyncedBudgets
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final item in items) {
      if (protectedMasterIds.contains(item.masterId) ||
          protectedBudgetIds.contains(item.id) ||
          deleting.protects(id: item.id, docno: item.code) ||
          deleting.protects(id: item.masterId, docno: item.code)) {
        continue;
      }
      batch.insert(
        'budget_source_master',
        {
          'id': item.masterId,
          'code': item.code,
          'name': item.name,
          'budget_type': item.budgetType,
          'refmoneygroup': item.refMoneyGroup,
          'refBankAccount': item.refBankAccount,
          'description': item.description,
          'synced': 1,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'budget_source_budget',
        {
          'id': item.id,
          'refBudgetSourceMaster': item.masterId,
          'fiscal_year': item.fiscalYear,
          'budget_amount': item.budgetAmount,
          'brought_forward_amount': item.broughtForwardAmount,
          'used_amount': item.usedAmount,
          'reserved_amount': item.reservedAmount,
          'synced': 1,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<BudgetSourceModel>> getAllBudgetSources() async {
    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery('''
        SELECT
          bb.id,
          bb.refBudgetSourceMaster AS masterId,
          bm.code,
          bm.name,
          bb.fiscal_year,
          bb.budget_amount,
          bb.brought_forward_amount,
          bb.used_amount,
          bb.reserved_amount,
          bm.budget_type,
          bm.refmoneygroup,
          bm.refBankAccount,
          bm.description,
          mg.name AS money_group_name,
          ba.accountname AS bank_account_name
        FROM budget_source_budget bb
        INNER JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
        LEFT JOIN money_group mg ON mg.id = bm.refmoneygroup
        LEFT JOIN bank_account ba ON ba.id = bm.refBankAccount
        ORDER BY bb.fiscal_year DESC, bm.code ASC
      ''');
    } catch (_) {
      // Backward-compat: DB schema บางรุ่นยังไม่มีคอลัมน์ `refmoneygroup`
      rows = await db.rawQuery('''
        SELECT
          bb.id,
          bb.refBudgetSourceMaster AS masterId,
          bm.code,
          bm.name,
          bb.fiscal_year,
          bb.budget_amount,
          bb.brought_forward_amount,
          bb.used_amount,
          bb.reserved_amount,
          bm.budget_type,
          bm.description
        FROM budget_source_budget bb
        INNER JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
        ORDER BY bb.fiscal_year DESC, bm.code ASC
      ''');
    }
    return rows.map((e) {
      final rawMg = e['refmoneygroup'];
      final rawBa = e['refBankAccount'];
      return BudgetSourceModel(
        id: e['id'] as String? ?? '',
        masterId: e['masterId'] as String? ?? '',
        code: e['code'] as String? ?? '',
        name: e['name'] as String? ?? '',
        fiscalYear: e['fiscal_year'] as String? ?? '',
        budgetAmount: (e['budget_amount'] as num?)?.toDouble() ?? 0,
        broughtForwardAmount:
            (e['brought_forward_amount'] as num?)?.toDouble() ?? 0,
        usedAmount: (e['used_amount'] as num?)?.toDouble() ?? 0,
        reservedAmount: (e['reserved_amount'] as num?)?.toDouble() ?? 0,
        budgetType: e['budget_type'] as String? ?? '',
        description: e['description'] as String?,
        refMoneyGroup: (rawMg == null || rawMg.toString().isEmpty)
            ? null
            : rawMg.toString(),
        moneyGroupName: e['money_group_name'] as String?,
        refBankAccount: (rawBa == null || rawBa.toString().isEmpty)
            ? null
            : rawBa.toString(),
        bankAccountName: e['bank_account_name'] as String?,
      );
    }).toList();
  }

  /// อ่านยอดงบปัจจุบันของแถว `budget_source_budget` (สำหรับตรวจสอบก่อนจ่าย)
  Future<BudgetBalanceSnapshot?> getBudgetBalanceSnapshot(
      String budgetRowId) async {
    if (budgetRowId.trim().isEmpty) return null;
    await ensureInitialized();
    final rows = await db.query(
      'budget_source_budget',
      columns: [
        'budget_amount',
        'brought_forward_amount',
        'used_amount',
        'reserved_amount',
      ],
      where: 'id = ?',
      whereArgs: [budgetRowId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    double d(Object? v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '0') ?? 0;

    return BudgetBalanceSnapshot(
      budgetAmount: d(r['budget_amount']),
      broughtForwardAmount: d(r['brought_forward_amount']),
      usedAmount: d(r['used_amount']),
      reservedAmount: d(r['reserved_amount']),
    );
  }

  /// เมื่อบันทึกรายจ่ายแล้ว: เพิ่ม `used_amount` และลด `reserved_amount` ตามยอดจ่าย
  /// (ลดกันเงินได้ไม่เกินยอดที่กันไว้ — ส่วนที่เกินจะเหลือ reserved = 0)
  Future<void> applyExpenseSpend({
    required String budgetRowId,
    required double spendAmount,
  }) async {
    if (budgetRowId.trim().isEmpty || spendAmount <= 0) return;
    await ensureInitialized();
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE budget_source_budget SET
        reserved_amount = reserved_amount - MIN(reserved_amount, ?),
        used_amount = used_amount + ?,
        lastModified = ?,
        synced = 0
      WHERE id = ?
      ''',
      [spendAmount, spendAmount, now, budgetRowId],
    );
  }

  /// ปรับเฉพาะ `used_amount` เมื่อแก้ไขรายการที่ถูกลงบัญชีไปแล้ว
  /// เพราะยอด `reserved_amount` ถูกเคลียร์ตอน post ครั้งแรกไปแล้ว
  Future<void> adjustPostedExpenseUsedAmount({
    required String budgetRowId,
    required double amountDelta,
  }) async {
    if (budgetRowId.trim().isEmpty || amountDelta.abs() < 0.005) return;
    await ensureInitialized();
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE budget_source_budget SET
        used_amount = MAX(0, used_amount + ?),
        lastModified = ?,
        synced = 0
      WHERE id = ?
      ''',
      [amountDelta, now, budgetRowId],
    );
  }

  Future<void> deleteBudgetSource(String id) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'budget_source_budget',
        columns: ['refBudgetSourceMaster'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final masterId = rows.first['refBudgetSourceMaster']?.toString() ?? '';
      await txn
          .delete('budget_source_budget', where: 'id = ?', whereArgs: [id]);
      final remain = await txn.rawQuery(
        'SELECT COUNT(1) AS c FROM budget_source_budget WHERE refBudgetSourceMaster = ?',
        [masterId],
      );
      final count = (remain.first['c'] as int?) ?? 0;
      if (count == 0) {
        await txn.delete('budget_source_master',
            where: 'id = ?', whereArgs: [masterId]);
      }
    });
  }
}
