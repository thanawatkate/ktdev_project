import 'package:sqflite/sqflite.dart';
import 'package:saccm/core/constants/offbudget_category_codes.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:saccm/core/utils/sqlite_money_field.dart';

class ExpenseModel {
  final String id;
  final String docno;
  final String docdate;
  final String detail;
  final String amount;
  final String remark;
  final String? refBudgetSource;
  final String? refExpenseReq;
  final String? refParty;
  final String? partyName;
  final String created;
  final bool synced;

  /// จาก expense_sub (ประเภทรายจ่าย พัสดุ)
  final String? refExpenseType;

  /// จาก expense_sub (หมวด OB / income_type)
  final String? refFundCategory;

  /// จาก expense_sub (money_type)
  final String? refMoneyType;

  /// workflow — TEAM_RULES §11.3 / §11.4
  final String? docStatus;
  final String? moneyDomain;
  final String? approvedBy;
  final String? approvedAt;
  final String? postedAt;
  final String? changeReason;

  ExpenseModel({
    required this.id,
    required this.docno,
    required this.docdate,
    required this.detail,
    required this.amount,
    required this.remark,
    this.refBudgetSource,
    this.refExpenseReq,
    this.refParty,
    this.partyName,
    required this.created,
    this.synced = true,
    this.refExpenseType,
    this.refFundCategory,
    this.refMoneyType,
    this.docStatus,
    this.moneyDomain,
    this.approvedBy,
    this.approvedAt,
    this.postedAt,
    this.changeReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'docno': docno,
        'docdate': docdate,
        'detail': detail,
        'amount': amount,
        'remark': remark,
        'refBudgetSource': refBudgetSource,
        'refExpenseReq': refExpenseReq,
        'refParty': refParty,
        'partyName': partyName,
        'created': created,
        'synced': synced ? 1 : 0,
        'refExpenseType': refExpenseType,
        'refFundCategory': refFundCategory,
        'refMoneyType': refMoneyType,
        'docStatus': docStatus,
        'moneyDomain': moneyDomain,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
        'postedAt': postedAt,
        'changeReason': changeReason,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as String? ?? '',
        docno: json['docno'] as String? ?? '',
        docdate: json['docdate'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        amount: sqliteMoneyToString(json['amount']),
        remark: json['remark'] as String? ?? '',
        refBudgetSource: json['refBudgetSource'] as String?,
        refExpenseReq:
            (json['refExpenseReq'] ?? json['refexpensereq'])?.toString(),
        refParty: json['refParty'] as String?,
        partyName: json['partyName'] as String?,
        created: json['created'] as String? ?? '',
        synced: (json['synced'] as int? ?? 1) == 1,
        refExpenseType: json['refExpenseType'] as String?,
        refFundCategory: json['refFundCategory'] as String?,
        refMoneyType: json['refMoneyType'] as String?,
        docStatus: json['docStatus'] as String?,
        moneyDomain: json['moneyDomain'] as String?,
        approvedBy: json['approvedBy'] as String?,
        approvedAt: json['approvedAt'] as String?,
        postedAt: json['postedAt'] as String?,
        changeReason: json['changeReason'] as String?,
      );
}

class ExpenseLocalDataSource extends BaseLocalDataSource {
  ExpenseModel _expenseModelFromJoinedRow(Map<String, dynamic> e) {
    return ExpenseModel(
      id: e['id'] as String? ?? '',
      docno: e['docno'] as String? ?? '',
      docdate: e['docdate'] as String? ?? '',
      detail: e['detail'] as String? ?? '',
      amount: sqliteMoneyToString(e['amount']),
      remark: e['remark'] as String? ?? '',
      refBudgetSource: e['refBudgetSource'] as String?,
      refExpenseReq: e['refExpenseReq'] as String?,
      refParty: e['refParty'] as String?,
      partyName: e['partyName'] as String?,
      created: e['created'] as String? ?? '',
      synced: (e['synced'] as int? ?? 1) == 1,
      refExpenseType: e['refExpenseType'] as String?,
      refFundCategory: e['refFundCategory'] as String?,
      refMoneyType: e['refMoneyType'] as String?,
      docStatus: e['docStatus']?.toString(),
      moneyDomain: e['moneyDomain']?.toString(),
      approvedBy: e['approvedBy']?.toString(),
      approvedAt: e['approvedAt']?.toString(),
      postedAt: e['postedAt']?.toString(),
      changeReason: e['changeReason']?.toString(),
    );
  }

  /// รูปแบบการจ่าย (money_type) สำหรับ dropdown — คืน [id, name, code]
  /// (page อ่าน id+name; code ใช้เพื่อจำแนก pocket cash/bank/cheque/agency)
  Future<List<List<String>>> getAllMoneyTypes() async {
    final rows = await db.query('money_type', orderBy: 'name ASC');
    return rows
        .map((r) => <String>[
              r['id']?.toString() ?? '',
              r['name']?.toString() ?? '',
              r['code']?.toString() ?? '',
            ])
        .where((r) => r[0].isNotEmpty)
        .toList();
  }

  /// วงเงินเก็บรักษา (cash_keeping_limit) ตาม fund_kind + school_size
  /// คืน null เมื่อไม่มีแถวที่ตรง (เช่น gov ไม่มี keep limit)
  Future<Map<String, double>?> getCashKeepingLimit({
    required String fundKind,
    required String schoolSize,
  }) async {
    final rows = await db.query(
      'cash_keeping_limit',
      where: 'fund_kind = ? AND school_size = ? AND is_active = 1',
      whereArgs: [fundKind, schoolSize],
      orderBy: 'fiscal_year DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return <String, double>{
      'cash_max': (row['cash_max'] is num
              ? (row['cash_max'] as num).toDouble()
              : double.tryParse(row['cash_max']?.toString() ?? '0')) ??
          0,
      'bank_max': (row['bank_max'] is num
              ? (row['bank_max'] as num).toDouble()
              : double.tryParse(row['bank_max']?.toString() ?? '0')) ??
          0,
    };
  }

  /// บัญชีเช็คที่ active สำหรับ dropdown — รวมชื่อธนาคารด้วย
  /// คืน [id, "{ca.chequename} ({bank.name})"]
  Future<List<List<String>>> getActiveChequeAccounts() async {
    final rows = await db.rawQuery('''
      SELECT
        ca.id          AS id,
        ca.chequename  AS chequename,
        ca.chequeno    AS chequeno,
        b.name         AS bank_name
      FROM cheque_account ca
      LEFT JOIN bank b ON b.id = ca.refBank
      WHERE COALESCE(ca.use, 'Y') = 'Y'
      ORDER BY ca.sort ASC, ca.chequename ASC
    ''');
    return rows
        .map((r) {
          final id = r['id']?.toString() ?? '';
          final name = r['chequename']?.toString() ?? '';
          final bank = r['bank_name']?.toString() ?? '';
          final no = r['chequeno']?.toString() ?? '';
          final parts = <String>[
            if (name.isNotEmpty) name,
            if (bank.isNotEmpty) '($bank)',
            if (no.isNotEmpty) '— เลขเริ่ม $no',
          ];
          final label = parts.isEmpty ? id : parts.join(' ');
          return <String>[id, label];
        })
        .where((r) => r[0].isNotEmpty)
        .toList();
  }

  /// หมวดเงินนอกงบประมาณสำหรับ dropdown รายจ่าย — กรอง OB ที่เป็น "รายรับเท่านั้น" (OB-10/12/13) ออก
  /// คืน [id, "code - name", code] เพื่อให้ page resolve `fund_kind` ของ keep limit ได้
  /// อ้างอิง: `OffBudgetCategoryCodes.incomeOnly` + คู่มือการเงินหน้า 6, 9
  Future<List<List<String>>> getOffBudgetFundCategories() async {
    final rows = await db.query(
      'income_type',
      where: 'code LIKE ?',
      whereArgs: <Object?>['OB-%'],
      orderBy: 'code ASC',
    );
    return rows
        .where(
            (e) => !OffBudgetCategoryCodes.isIncomeOnly(e['code']?.toString()))
        .map((e) => <String>[
              e['id']?.toString() ?? '',
              '${e['code'] ?? ''} - ${e['name'] ?? ''}',
              e['code']?.toString() ?? '',
            ])
        .where((r) => r[0].isNotEmpty)
        .toList();
  }

  Future<void> saveExpenseSub({
    required String id,
    required String refExpense,
    String? refExpenseType,
    String? refFundCategory,
    String? refMoneyType,
    required String amount,
    required String remark,
    bool synced = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'expense_sub',
      {
        'id': id,
        'refExpense': refExpense,
        'refExpenseType': refExpenseType,
        'refFundCategory': refFundCategory,
        'refMoneyType': refMoneyType,
        'amount': sqliteMoneyToDouble(amount),
        'remark': remark,
        'created': now,
        'updated': now,
        'synced': synced ? 1 : 0,
        'lastModified': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExpenseSubsForExpense(String refExpense) async {
    await db.delete(
      'expense_sub',
      where: 'refExpense = ?',
      whereArgs: [refExpense],
    );
  }

  /// แถว expense_sub ทั้งหมดของใบรายจ่าย (เรียง id)
  Future<List<Map<String, dynamic>>> getExpenseSubsForExpense(
    String refExpense,
  ) async {
    final rows = await db.query(
      'expense_sub',
      where: 'refExpense = ?',
      whereArgs: [refExpense],
      orderBy: 'id ASC',
    );
    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<void> deletePayChequesForExpense(String refExpense) async {
    await db.delete(
      'pay_cheque',
      where: 'refExpense = ?',
      whereArgs: [refExpense],
    );
  }

  Future<void> savePayCheque({
    required String id,
    required String refExpense,
    String? refChequeAccount,
    required String chequeamount,
    String? chequeno,
    String remark = '',
    String? clearedAt,
    bool synced = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'pay_cheque',
      {
        'id': id,
        'chequeamount': sqliteMoneyToDouble(chequeamount),
        'chequeno': chequeno,
        'remark': remark,
        'cleared_at': clearedAt,
        'refChequeAccount': refChequeAccount,
        'refExpense': refExpense,
        'created': now,
        'updated': now,
        'synced': synced ? 1 : 0,
        'lastModified': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPayChequesForExpense(
    String refExpense,
  ) async {
    final rows = await db.query(
      'pay_cheque',
      where: 'refExpense = ?',
      whereArgs: [refExpense],
      orderBy: 'id ASC',
    );
    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<void> markPayChequeCleared(String id, {bool cleared = true}) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'pay_cheque',
      {
        'cleared_at': cleared ? now : null,
        'updated': now,
        'synced': 0,
        'lastModified': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// แถว pay_cheque แรกของใบรายจ่าย (backward-compat)
  Future<Map<String, dynamic>?> getPayChequeFirstForExpense(
    String refExpense,
  ) async {
    final rows = await getPayChequesForExpense(refExpense);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Map<String, Object?> _expenseInsertMap(ExpenseModel expense, bool synced) {
    return {
      'id': expense.id,
      'docno': expense.docno,
      'docdate': expense.docdate,
      'detail': expense.detail,
      'amount': sqliteMoneyToDouble(expense.amount),
      'remark': expense.remark,
      'refBudgetSource': expense.refBudgetSource,
      'refExpenseReq': expense.refExpenseReq,
      'refParty': expense.refParty,
      'partyName': expense.partyName,
      'docStatus': expense.docStatus ?? 'posted',
      'moneyDomain': expense.moneyDomain,
      'approvedBy': expense.approvedBy,
      'approvedAt': expense.approvedAt,
      'postedAt': expense.postedAt,
      'changeReason': expense.changeReason,
      'created': expense.created,
      'synced': synced ? 1 : 0,
      'lastModified': DateTime.now().toIso8601String(),
    };
  }

  /// บันทึก expense ลง local database
  Future<void> saveExpense(ExpenseModel expense, {bool synced = true}) async {
    await db.insert(
      'expense',
      _expenseInsertMap(expense, synced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// บันทึก multiple expenses
  Future<void> saveExpenses(List<ExpenseModel> expenses) async {
    final deleting = await pendingDeleteProtectionFor('expense_delete_');
    final unsyncedRows = await db.query(
      'expense',
      columns: ['id'],
      where: 'synced = 0',
    );
    final protectedIds = unsyncedRows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final batch = db.batch();
    for (final expense in expenses) {
      if (protectedIds.contains(expense.id) ||
          deleting.protects(id: expense.id, docno: expense.docno)) {
        continue;
      }
      batch.insert(
        'expense',
        _expenseInsertMap(expense, true),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// ดึง expense ทั้งหมดจาก local database
  Future<List<ExpenseModel>> getAllExpenses() async {
    final results = await db.rawQuery('''
      SELECT
        e.id AS id,
        e.docno AS docno,
        e.docdate AS docdate,
        e.detail AS detail,
        e.amount AS amount,
        e.remark AS remark,
        e.refBudgetSource AS refBudgetSource,
        e.refExpenseReq AS refExpenseReq,
        e.refParty AS refParty,
        e.partyName AS partyName,
        e.docStatus AS docStatus,
        e.moneyDomain AS moneyDomain,
        e.approvedBy AS approvedBy,
        e.approvedAt AS approvedAt,
        e.postedAt AS postedAt,
        e.changeReason AS changeReason,
        e.created AS created,
        e.synced AS synced,
        (SELECT s.refExpenseType FROM expense_sub s
         WHERE s.refExpense = e.id ORDER BY s.id LIMIT 1) AS refExpenseType,
        (SELECT s.refFundCategory FROM expense_sub s
         WHERE s.refExpense = e.id ORDER BY s.id LIMIT 1) AS refFundCategory,
        (SELECT s.refMoneyType FROM expense_sub s
         WHERE s.refExpense = e.id ORDER BY s.id LIMIT 1) AS refMoneyType
      FROM expense e
      ORDER BY e.docdate DESC
    ''');
    return results.map(_expenseModelFromJoinedRow).toList();
  }

  Future<({double total, int count})> getDashboardSummaryTotals() async {
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CAST(amount AS REAL)), 0) AS total,
        COUNT(*) AS count
      FROM expense
    ''');
    final row = rows.first;
    final total = (row['total'] as num?)?.toDouble() ??
        double.tryParse(row['total']?.toString() ?? '0') ??
        0.0;
    final count = (row['count'] as num?)?.toInt() ??
        int.tryParse(row['count']?.toString() ?? '0') ??
        0;
    return (total: total, count: count);
  }

  Future<Map<String, double>> getDashboardMonthlyTotals({
    required String startMonth,
  }) async {
    final rows = await db.rawQuery('''
      SELECT
        substr(docdate, 1, 7) AS month_key,
        COALESCE(SUM(CAST(amount AS REAL)), 0) AS total
      FROM expense
      WHERE docdate >= ?
      GROUP BY substr(docdate, 1, 7)
    ''', ['$startMonth-01']);
    return {
      for (final row in rows)
        row['month_key']?.toString() ?? '':
            (row['total'] as num?)?.toDouble() ??
                double.tryParse(row['total']?.toString() ?? '0') ??
                0.0,
    }..remove('');
  }

  /// ดึง expense ตาม id
  Future<ExpenseModel?> getExpenseById(String id) async {
    final results = await db.rawQuery('''
      SELECT
        e.id AS id,
        e.docno AS docno,
        e.docdate AS docdate,
        e.detail AS detail,
        e.amount AS amount,
        e.remark AS remark,
        e.refBudgetSource AS refBudgetSource,
        e.refExpenseReq AS refExpenseReq,
        e.refParty AS refParty,
        e.partyName AS partyName,
        e.docStatus AS docStatus,
        e.moneyDomain AS moneyDomain,
        e.approvedBy AS approvedBy,
        e.approvedAt AS approvedAt,
        e.postedAt AS postedAt,
        e.changeReason AS changeReason,
        e.created AS created,
        e.synced AS synced,
        (SELECT s.refExpenseType FROM expense_sub s
         WHERE s.refExpense = e.id ORDER BY s.id LIMIT 1) AS refExpenseType,
        (SELECT s.refFundCategory FROM expense_sub s
         WHERE s.refExpense = e.id ORDER BY s.id LIMIT 1) AS refFundCategory,
        (SELECT s.refMoneyType FROM expense_sub s
         WHERE s.refExpense = e.id ORDER BY s.id LIMIT 1) AS refMoneyType
      FROM expense e
      WHERE e.id = ?
      LIMIT 1
    ''', [id]);

    if (results.isEmpty) return null;
    return _expenseModelFromJoinedRow(results.first);
  }

  /// ลบ expense จาก local database
  Future<void> deleteExpense(String id) async {
    await db.delete('expense', where: 'id = ?', whereArgs: [id]);
  }

  /// ล้าง expense ทั้งหมด
  Future<void> clearAllExpenses() async {
    await db.delete('expense');
  }

  /// Mark expense as synced
  Future<void> markAsSynced(String id) async {
    await db.update(
      'expense',
      {
        'synced': 1,
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// ดึงประเภทรายจ่ายทั้งหมดจาก local database (expense_type)
  Future<List<List<String>>> getAllExpenseTypes() async {
    final rows = await db.query(
      'expense_type',
      where: "use = 'Y'",
      orderBy: 'sort ASC',
    );
    return rows
        .map((e) => [
              e['id'] as String? ?? '',
              '${e['code'] ?? ''} - ${e['name'] ?? ''}',
              e['refDefaultBudgetSource'] as String? ?? '',
            ])
        .toList();
  }
}
