import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:saccm/core/utils/sqlite_money_field.dart';
import 'package:sqflite/sqflite.dart';

class LoanModel {
  final String id;
  final String? serverId;
  final String docno;
  final String loandate;
  final String duedate;
  final String amount;
  final double openingOutstanding;
  final String remark;
  final String refMember;

  /// ข้อความแสดงผู้ยืม (จาก JOIN ทะเบียนสมาชิก หรือค่าเดิมใน refMember)
  final String borrowerDisplay;
  final String created;
  final bool synced;
  final double outstanding;
  final bool isOverdue;

  LoanModel({
    required this.id,
    this.serverId,
    required this.docno,
    required this.loandate,
    required this.duedate,
    required this.amount,
    this.openingOutstanding = 0,
    required this.remark,
    required this.refMember,
    this.borrowerDisplay = '',
    required this.created,
    this.synced = true,
    this.outstanding = 0,
    this.isOverdue = false,
  });

  String get borrowerLabel =>
      borrowerDisplay.isNotEmpty ? borrowerDisplay : refMember;

  String get effectiveServerId =>
      serverId?.trim().isNotEmpty == true ? serverId!.trim() : id;
}

/// แถว `loan_sub` — `refFundCategory` อ้าง `income_type.id`
class LoanSubPersistRow {
  const LoanSubPersistRow({
    required this.id,
    required this.refLoan,
    required this.refFundCategory,
    required this.amount,
    this.remark = '',
    required this.created,
  });

  final String id;
  final String refLoan;
  final String refFundCategory;
  final double amount;
  final String remark;
  final String created;

  factory LoanSubPersistRow.fromMap(Map<String, dynamic> e) {
    final rawAmt = e['amount'];
    final amt = rawAmt is num
        ? rawAmt.toDouble()
        : double.tryParse(rawAmt?.toString() ?? '0') ?? 0;
    return LoanSubPersistRow(
      id: e['id']?.toString() ?? '',
      refLoan: e['refLoan']?.toString() ?? '',
      refFundCategory: e['refFundCategory']?.toString() ?? '',
      amount: amt,
      remark: e['remark']?.toString() ?? '',
      created: e['created']?.toString() ?? '',
    );
  }
}

class LoanLocalDataSource extends BaseLocalDataSource {
  static String borrowerDisplayFromJoinedRow(Map<String, dynamic> e) {
    final name = (e['member_name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) {
      final code = (e['member_code'] as String?)?.trim() ?? '';
      if (code.isNotEmpty) return '$code — $name';
      return name;
    }
    return (e['refMember'] as String?)?.trim() ?? '';
  }

  Future<void> saveLoan(LoanModel loan, {bool synced = true}) async {
    await db.insert(
      'loan',
      {
        'id': loan.id,
        'server_id': loan.serverId,
        'docno': loan.docno,
        'loandate': loan.loandate,
        'duedate': loan.duedate,
        'amount': sqliteMoneyToDouble(loan.amount),
        'opening_outstanding': loan.openingOutstanding,
        'remark': loan.remark,
        'refMember': loan.refMember,
        'created': loan.created,
        'updated': DateTime.now().toIso8601String(),
        'synced': synced ? 1 : 0,
        'lastModified': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// แมป refLoan (id หรือ docno เก่า) → loan.id
  Future<Map<String, String>> _loanRefToIdMap() async {
    final rows = await db.query('loan', columns: ['id', 'server_id', 'docno']);
    final map = <String, String>{};
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final serverId = row['server_id']?.toString() ?? '';
      final docno = row['docno']?.toString() ?? '';
      if (id.isNotEmpty) map[id] = id;
      if (serverId.isNotEmpty) map[serverId] = id;
      if (docno.isNotEmpty) map[docno] = id;
    }
    return map;
  }

  String _resolveLoanId(String ref, Map<String, String> refToId) =>
      refToId[ref] ?? ref;

  Future<String?> docnoForLoanRef(String refLoanOrId) async {
    final ref = refLoanOrId.trim();
    if (ref.isEmpty) return null;
    final byId = await db.query(
      'loan',
      columns: ['docno'],
      where: 'id = ?',
      whereArgs: [ref],
      limit: 1,
    );
    if (byId.isNotEmpty) {
      return byId.first['docno']?.toString();
    }
    final byDocno = await db.query(
      'loan',
      columns: ['docno'],
      where: 'docno = ? OR server_id = ?',
      whereArgs: [ref, ref],
      limit: 1,
    );
    if (byDocno.isNotEmpty) {
      return byDocno.first['docno']?.toString();
    }
    return null;
  }

  Future<List<LoanModel>> getAllLoans() async {
    final rows = await db.rawQuery(
      'SELECT l.*, m.code AS member_code, m.name AS member_name '
      'FROM loan l '
      'LEFT JOIN member m ON m.id = l.refMember '
      'ORDER BY l.created DESC',
    );
    final refToId = await _loanRefToIdMap();
    final repayRows = await db.rawQuery(
      'SELECT refLoan, COALESCE(SUM(CAST(amount AS REAL)),0) AS repaid '
      'FROM repay_loan GROUP BY refLoan',
    );
    final repaidByLoanId = <String, double>{};
    for (final row in repayRows) {
      final raw = row['refLoan']?.toString() ?? '';
      if (raw.isEmpty) continue;
      final loanId = _resolveLoanId(raw, refToId);
      if (loanId.isEmpty) continue;
      repaidByLoanId[loanId] = (repaidByLoanId[loanId] ?? 0) +
          ((row['repaid'] as num?)?.toDouble() ?? 0);
    }
    final now = DateTime.now();
    return rows.map((e) {
      final loanId = e['id'] as String? ?? '';
      final docno = e['docno'] as String? ?? '';
      final amount = double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
      final opening = (e['opening_outstanding'] as num?)?.toDouble() ??
          double.tryParse(e['opening_outstanding']?.toString() ?? '0') ??
          0;
      final dueDateRaw = e['duedate'] as String? ?? '';
      final dueDate = DateTime.tryParse(dueDateRaw);
      final repaid = repaidByLoanId[loanId] ?? 0;
      final outstanding = (amount + opening) - repaid;
      return LoanModel(
        id: e['id'] as String? ?? '',
        serverId: e['server_id']?.toString(),
        docno: docno,
        loandate: e['loandate'] as String? ?? '',
        duedate: dueDateRaw,
        amount: sqliteMoneyToString(e['amount']),
        openingOutstanding: opening,
        remark: e['remark'] as String? ?? '',
        refMember: e['refMember'] as String? ?? '',
        borrowerDisplay: borrowerDisplayFromJoinedRow(e),
        created: e['created'] as String? ?? '',
        synced: (e['synced'] as int? ?? 1) == 1,
        outstanding: outstanding > 0 ? outstanding : 0,
        isOverdue: dueDate != null &&
            outstanding > 0 &&
            dueDate.isBefore(DateTime(now.year, now.month, now.day)),
      );
    }).toList();
  }

  Future<LoanModel?> getLoanById(String id) async {
    final rows = await db.query('loan', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final e = rows.first;
    final ref = e['refMember'] as String? ?? '';
    var display = '';
    if (ref.isNotEmpty) {
      final m = await db.query(
        'member',
        columns: ['code', 'name'],
        where: 'id = ?',
        whereArgs: [ref],
        limit: 1,
      );
      if (m.isNotEmpty) {
        final code = (m.first['code'] as String?)?.trim() ?? '';
        final name = (m.first['name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty) {
          display = code.isNotEmpty ? '$code — $name' : name;
        }
      }
    }
    if (display.isEmpty) display = ref;
    return LoanModel(
      id: e['id'] as String? ?? '',
      serverId: e['server_id']?.toString(),
      docno: e['docno'] as String? ?? '',
      loandate: e['loandate'] as String? ?? '',
      duedate: e['duedate'] as String? ?? '',
      amount: sqliteMoneyToString(e['amount']),
      openingOutstanding: (e['opening_outstanding'] as num?)?.toDouble() ?? 0,
      remark: e['remark'] as String? ?? '',
      refMember: ref,
      borrowerDisplay: display,
      created: e['created'] as String? ?? '',
      synced: (e['synced'] as int? ?? 1) == 1,
      outstanding: 0,
      isOverdue: false,
    );
  }

  Future<void> markAsSynced(String id) async {
    await db.update(
      'loan',
      {
        'synced': 1,
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> applyServerId(String localId, String serverId) async {
    final normalized = serverId.trim();
    if (localId.isEmpty || normalized.isEmpty) return;
    await db.update(
      'loan',
      {
        'server_id': normalized,
        'synced': 1,
        'updated': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteLoan(String id) async {
    await db.delete('loan', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<LoanSubPersistRow>> getLoanSubs(String loanId) async {
    if (loanId.isEmpty) return const [];
    final rows = await db.query(
      'loan_sub',
      where: 'refLoan = ?',
      whereArgs: [loanId],
      orderBy: 'created ASC, id ASC',
    );
    return rows.map(LoanSubPersistRow.fromMap).toList();
  }

  /// แทนที่รายการย่อยทั้งหมดของใบยืม (หลังบันทึกหัวใบ)
  Future<void> replaceLoanSubs(
    String loanId,
    List<LoanSubPersistRow> subs, {
    bool synced = false,
  }) async {
    if (loanId.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    batch.delete('loan_sub', where: 'refLoan = ?', whereArgs: [loanId]);
    var i = 0;
    for (final s in subs) {
      final id = s.id.isNotEmpty
          ? s.id
          : '${loanId}_sub_${DateTime.now().microsecondsSinceEpoch}_$i';
      batch.insert(
        'loan_sub',
        {
          'id': id,
          'refLoan': loanId,
          'refFundCategory': s.refFundCategory,
          'amount': s.amount,
          'remark': s.remark,
          'created': s.created.isNotEmpty ? s.created : now,
          'updated': now,
          'synced': synced ? 1 : 0,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      i++;
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> findActiveOutstandingLoanByBorrower(
    String borrower, {
    String? excludeLoanId,
  }) async {
    final normalizedBorrower = borrower.trim();
    if (normalizedBorrower.isEmpty) return null;
    final loans = await db.query(
      'loan',
      columns: [
        'id',
        'server_id',
        'docno',
        'amount',
        'opening_outstanding',
        'duedate'
      ],
      where: 'TRIM(refMember) = ?',
      whereArgs: [normalizedBorrower],
      orderBy: 'created DESC',
    );
    for (final loan in loans) {
      final loanId = loan['id']?.toString() ?? '';
      final serverId = loan['server_id']?.toString() ?? '';
      if (excludeLoanId != null && excludeLoanId == loanId) continue;
      final docno = loan['docno']?.toString() ?? '';
      if (docno.isEmpty) continue;
      final principal = double.tryParse(loan['amount']?.toString() ?? '0') ?? 0;
      final opening = (loan['opening_outstanding'] as num?)?.toDouble() ??
          double.tryParse(loan['opening_outstanding']?.toString() ?? '0') ??
          0;
      final repayRows = await db.rawQuery(
        'SELECT COALESCE(SUM(CAST(amount AS REAL)),0) AS repaid '
        'FROM repay_loan WHERE refLoan IN (?, ?, ?)',
        [loanId, serverId, docno],
      );
      final repaid = (repayRows.first['repaid'] as num?)?.toDouble() ?? 0;
      final outstanding = (principal + opening) - repaid;
      if (outstanding > 0.0001) {
        return {
          'loanId': loanId,
          'docno': docno,
          'outstanding': outstanding,
          'duedate': loan['duedate']?.toString() ?? '',
        };
      }
    }
    return null;
  }
}
