import 'dart:math' as math;

import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/utils/pocket_classifier.dart';
import 'package:saccm/core/utils/sqlite_money_field.dart';

/// Local data source สำหรับโมดูลทะเบียนคุม (SQLite-first ตาม TEAM_RULES §4.2)
/// ทุก method คืนผลเป็นรายการของ Map (key เป็น String) ที่ใช้ key เดิมจาก cellBuilder
class RegisterLocalDataSource {
  final AppDatabase _db = AppDatabase();

  // ── helpers ──────────────────────────────────────────────────────────────

  /// แปลงปีงบประมาณ พ.ศ. → ช่วงวันที่ ISO (ต.ค.CE-1 — ก.ย.CE)
  static (String start, String end) _fyRange(int thaiYear) {
    final ce = thaiYear - 543;
    final start = '${ce - 1}-10-01';
    final end = '$ce-09-30T23:59:59';
    return (start, end);
  }

  Future<void> _ensureDb() async {
    await _db.database; // warm up singleton
  }

  Future<bool> isDailyClosed(String date) async {
    await _ensureDb();
    final db = await _db.database;
    final rows = await db.query(
      'daily_closing',
      where: 'close_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// เลขที่ใบเสร็จถัดไปที่คาดหวัง (แสดงในฟอร์มรายรับ) — null ถ้าไม่พบเล่มหรือรูปแบบไม่ถูกต้อง
  Future<String?> suggestedNextReceiptNo(String bookId) async {
    await _ensureDb();
    final db = await _db.database;
    final books = await db.query(
      'receipt_book',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (books.isEmpty) return null;
    final b = books.first;
    final startRaw = b['start_no']?.toString().trim() ?? '';
    final nStart = int.tryParse(startRaw.replaceAll(RegExp(r'[^0-9]'), ''));
    if (nStart == null) return null;
    final issues = await db.query(
      'receipt_issue',
      columns: ['receipt_no'],
      where: 'ref_book = ?',
      whereArgs: [bookId],
    );
    var maxIssued = 0;
    for (final row in issues) {
      final n = int.tryParse(
        (row['receipt_no'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (n != null && n > maxIssued) maxIssued = n;
    }
    final expected = maxIssued == 0 ? nStart : maxIssued + 1;
    final w = math.max(
      1,
      math.min(
        12,
        math.max(
          startRaw.replaceAll(RegExp(r'[^0-9]'), '').length,
          expected.toString().length,
        ),
      ),
    );
    return expected.toString().padLeft(w, '0');
  }

  // ── 1. หลักฐานขอเบิก (expense_req) ────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEvidenceRegister(
      {int? fiscalYear}) async {
    await _ensureDb();
    final db = await _db.database;

    String? whereClause;
    List<Object?>? whereArgs;
    if (fiscalYear != null) {
      final (start, end) = _fyRange(fiscalYear);
      whereClause = "created >= ? AND created <= ?";
      whereArgs = [start, end];
    }

    final rows = await db.query(
      'expense_req',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created DESC',
    );

    return rows.map((r) {
      final status = r['approval_status']?.toString();
      return {
        'docdate': r['docdate'] ?? r['created'],
        'docno': r['docno'],
        'detail': r['detail'] ?? r['remark'],
        'budget_source_name': r['budget_source_name']?.toString() ?? '-',
        'amount': r['amount'] ?? '0',
        'approval_status':
            (status != null && status.isNotEmpty) ? status : 'draft',
      };
    }).toList();
  }

  // ── 2. ใบสำคัญคู่จ่าย (expense) ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getVoucherRegister(
      {int? fiscalYear}) async {
    await _ensureDb();
    final db = await _db.database;

    String? whereClause;
    List<Object?>? whereArgs;
    if (fiscalYear != null) {
      final (start, end) = _fyRange(fiscalYear);
      whereClause = "e.docdate >= ? AND e.docdate <= ?";
      whereArgs = [start, end];
    }

    // JOIN budget_source_master via budget_source_budget
    final rows = await db.rawQuery('''
      SELECT
        e.docdate,
        e.docno,
        e.detail,
        e.amount,
        e.partyName  AS receiver,
        COALESCE(bsm.name, '-') AS budget_source_name
      FROM expense e
      LEFT JOIN budget_source_budget bsb ON bsb.id = e.refBudgetSource
      LEFT JOIN budget_source_master bsm ON bsm.id = bsb.refBudgetSourceMaster
      ${whereClause != null ? 'WHERE $whereClause' : ''}
      ORDER BY e.docdate DESC
    ''', whereArgs);

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ── 3. การจ่ายเช็ค (pay_cheque + joins) ────────────────────────────────

  Future<List<Map<String, dynamic>>> getChequeRegister(
      {int? fiscalYear}) async {
    await _ensureDb();
    final db = await _db.database;

    String? fyCond;
    List<Object?>? whereArgs;
    if (fiscalYear != null) {
      final (start, end) = _fyRange(fiscalYear);
      fyCond = "e.docdate >= ? AND e.docdate <= ?";
      whereArgs = [start, end];
    }

    final rows = await db.rawQuery('''
      SELECT
        pc.id                                   AS pay_cheque_id,
        e.docdate                               AS docdate,
        pc.chequeno                             AS chequeno,
        pc.cleared_at                           AS cleared_at,
        b.name                                  AS bank_name,
        COALESCE(ca.chequename, ca.chequeno, '') AS cheque_account_no,
        COALESCE(e.detail, pc.remark, '')       AS expense_detail,
        COALESCE(pc.chequeamount, e.amount, '0') AS amount
      FROM pay_cheque pc
      LEFT JOIN cheque_account ca ON ca.id = pc.refChequeAccount
      LEFT JOIN bank b            ON b.id  = ca.refBank
      LEFT JOIN expense e         ON e.id  = pc.refExpense
      ${fyCond != null ? 'WHERE $fyCond' : ''}
      ORDER BY e.docdate DESC
    ''', whereArgs);

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// เช็คที่ยังไม่ตัดบัญชี (cleared_at ว่าง) — สำหรับรายงานเช็คค้าง
  Future<List<Map<String, dynamic>>> getOutstandingCheques({
    int? fiscalYear,
  }) async {
    await _ensureDb();
    final db = await _db.database;

    String? fyCond;
    List<Object?>? whereArgs;
    if (fiscalYear != null) {
      final (start, end) = _fyRange(fiscalYear);
      fyCond =
          "e.docdate >= ? AND e.docdate <= ? AND (pc.cleared_at IS NULL OR TRIM(pc.cleared_at) = '')";
      whereArgs = [start, end];
    } else {
      fyCond = "(pc.cleared_at IS NULL OR TRIM(pc.cleared_at) = '')";
    }

    final rows = await db.rawQuery('''
      SELECT
        pc.id                                   AS pay_cheque_id,
        e.docdate                               AS docdate,
        pc.chequeno                             AS chequeno,
        b.name                                  AS bank_name,
        COALESCE(ca.chequename, ca.chequeno, '') AS cheque_account_no,
        COALESCE(e.detail, pc.remark, '')       AS expense_detail,
        e.docno                                 AS expense_docno,
        COALESCE(pc.chequeamount, e.amount, '0') AS amount
      FROM pay_cheque pc
      LEFT JOIN cheque_account ca ON ca.id = pc.refChequeAccount
      LEFT JOIN bank b            ON b.id  = ca.refBank
      LEFT JOIN expense e         ON e.id  = pc.refExpense
      ${'WHERE $fyCond'}
      ORDER BY e.docdate ASC, pc.id ASC
    ''', whereArgs);

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ── 4. สัญญายืมเงิน (loan + repay_loan + member) ──────────────────────

  Future<List<Map<String, dynamic>>> getLoanRegister({int? fiscalYear}) async {
    await _ensureDb();
    final db = await _db.database;

    String? fyCond;
    List<Object?>? whereArgs;
    if (fiscalYear != null) {
      final (start, end) = _fyRange(fiscalYear);
      fyCond = "l.loandate >= ? AND l.loandate <= ?";
      whereArgs = [start, end];
    }

    final rows = await db.rawQuery('''
      SELECT
        l.id,
        l.docno,
        l.loandate,
        l.duedate,
        COALESCE(l.amount, '0')                         AS loan_amount,
        COALESCE(l.opening_outstanding, 0)              AS opening_outstanding,
        COALESCE(m.name, '-')                           AS borrower,
        COALESCE(
          (SELECT SUM(CAST(rl.amount AS REAL))
           FROM repay_loan rl WHERE rl.refLoan = l.id), 0
        )                                               AS repay_total_num,
        COALESCE(l.amount, '0')                         AS _loan_amt_str
      FROM loan l
      LEFT JOIN member m ON m.id = l.refMember
      ${fyCond != null ? 'WHERE $fyCond' : ''}
      ORDER BY l.loandate DESC
    ''', whereArgs);

    return rows.map((r) {
      final loanAmt = double.tryParse(r['loan_amount']?.toString() ?? '0') ?? 0;
      final opening = (r['opening_outstanding'] as num?)?.toDouble() ??
          double.tryParse(r['opening_outstanding']?.toString() ?? '0') ??
          0;
      final repayTot = (r['repay_total_num'] as num?)?.toDouble() ?? 0;
      final outstanding = (loanAmt + opening) - repayTot;
      return <String, dynamic>{
        'loandate': r['loandate'],
        'docno': r['docno'],
        'borrower': r['borrower'],
        'loan_amount': loanAmt.toStringAsFixed(2),
        'repay_total': repayTot.toStringAsFixed(2),
        'outstanding': (outstanding > 0 ? outstanding : 0).toStringAsFixed(2),
        'duedate': r['duedate'],
      };
    }).toList();
  }

  // ── 5. ใบเสร็จรับเงิน (receipt_book + receipt_issue) ──────────────────

  Future<List<Map<String, dynamic>>> listReceiptBooks(
      {String? fiscalYear}) async {
    await _ensureDb();
    final db = await _db.database;

    final rows = await db.rawQuery('''
      SELECT
        rb.id,
        rb.book_no,
        rb.receipt_type,
        rb.start_no,
        rb.end_no,
        rb.fiscal_year,
        rb.status,
        COUNT(ri.id)              AS used_count,
        COALESCE(SUM(ri.amount), 0) AS used_amount
      FROM receipt_book rb
      LEFT JOIN receipt_issue ri ON ri.ref_book = rb.id
      ${fiscalYear != null ? "WHERE rb.fiscal_year = ?" : ""}
      GROUP BY rb.id
      ORDER BY rb.fiscal_year DESC, rb.book_no ASC
    ''', fiscalYear != null ? [fiscalYear] : null);

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> upsertReceiptBooksFromRemote(
    List<Map<String, dynamic>> rows,
  ) async {
    await _ensureDb();
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final r in rows) {
      final id = r['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        'receipt_book',
        {
          'id': id,
          'book_no': r['book_no']?.toString() ?? '',
          'receipt_type': r['receipt_type']?.toString() ?? 'บร.',
          'start_no': r['start_no']?.toString() ?? '',
          'end_no': r['end_no']?.toString() ?? '',
          'fiscal_year': r['fiscal_year']?.toString() ?? '',
          'status': r['status']?.toString() ?? 'available',
          'received_at': r['received_at']?.toString(),
          'received_from': r['received_from']?.toString(),
          'remark': r['remark']?.toString(),
          'created': r['created']?.toString() ?? now,
          'updated': r['updated']?.toString() ?? now,
          'synced': int.tryParse(r['synced']?.toString() ?? '') ?? 1,
          'last_modified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertReceiptBookLocal(Map<String, dynamic> row) async {
    await upsertReceiptBooksFromRemote([row]);
  }

  Future<void> markReceiptBookSynced(
    String localId, {
    String? serverId,
  }) async {
    await _ensureDb();
    final db = await _db.database;
    final normalizedServerId = serverId?.trim();
    await db.transaction((txn) async {
      if (normalizedServerId != null &&
          normalizedServerId.isNotEmpty &&
          normalizedServerId != localId) {
        final serverRows = await txn.query(
          'receipt_book',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [normalizedServerId],
          limit: 1,
        );
        if (serverRows.isNotEmpty) {
          await txn.delete(
            'receipt_book',
            where: 'id = ?',
            whereArgs: [localId],
          );
          await txn.update(
            'receipt_book',
            {
              'synced': 1,
              'updated': DateTime.now().toIso8601String(),
              'last_modified': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [normalizedServerId],
          );
          return;
        }
        await txn.update(
          'receipt_book',
          {
            'id': normalizedServerId,
            'synced': 1,
            'updated': DateTime.now().toIso8601String(),
            'last_modified': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [localId],
        );
        return;
      }

      await txn.update(
        'receipt_book',
        {
          'synced': 1,
          'updated': DateTime.now().toIso8601String(),
          'last_modified': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
    });
  }

  Future<int> countReceiptBookUsage(String bookId) async {
    await _ensureDb();
    final db = await _db.database;
    final issueRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM receipt_issue WHERE ref_book = ?',
      [bookId],
    );
    final issueValue = issueRows.first['c'];
    return issueValue is int
        ? issueValue
        : int.tryParse(issueValue?.toString() ?? '') ?? 0;
  }

  Future<void> deleteReceiptBookLocal(String bookId) async {
    await _ensureDb();
    final db = await _db.database;
    await db.delete(
      'receipt_book',
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  // ── 6. เงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย (deposit_guarantee) ────────

  Future<List<Map<String, dynamic>>> listDeposits({
    String? fiscalYear,
    String? status,
    String? depositType,
  }) async {
    await _ensureDb();
    final db = await _db.database;

    final conditions = <String>[];
    final args = <Object?>[];

    if (fiscalYear != null) {
      conditions.add('fiscal_year = ?');
      args.add(fiscalYear);
    }
    if (status != null) {
      conditions.add('status = ?');
      args.add(status);
    }
    if (depositType != null && depositType.trim().isNotEmpty) {
      conditions.add('deposit_type = ?');
      args.add(depositType.trim());
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');

    final rows = await db.query(
      'deposit_guarantee',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created DESC',
    );

    return rows.map((r) => _mapDepositRow(r)).toList();
  }

  Map<String, dynamic> _mapDepositRow(Map<String, Object?> r) {
    return <String, dynamic>{
      'id': r['id'],
      'docdate': r['docdate'],
      'docno': r['docno'],
      'deposit_type': r['deposit_type'],
      'amount': r['amount'],
      'party_name': r['party_name_snapshot'],
      'party_name_snapshot': r['party_name_snapshot'],
      'contract_no': r['contract_no'],
      'detail': r['detail'],
      'due_date': r['due_date'],
      'status': r['status'],
      'fiscal_year': r['fiscal_year'],
      'ref_income_id': r['ref_income_id'],
      'ref_expense_id': r['ref_expense_id'],
      'income_docno': r['income_docno'],
      'expense_docno': r['expense_docno'],
      'settled_at': r['settled_at'],
      'settled_docno': r['settled_docno'],
      'settled_remark': r['settled_remark'],
    };
  }

  /// บันทึก/อัปเดตแถวทะเบียนจาก API หรือ mirror sync
  Future<void> upsertDepositFromServer(Map<String, dynamic> raw) async {
    await _ensureDb();
    final db = await _db.database;
    final id = raw['id']?.toString() ?? raw['deposit_id']?.toString() ?? '';
    if (id.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    await db.insert(
      'deposit_guarantee',
      {
        'id': id,
        'docno': raw['docno']?.toString() ?? '',
        'docdate': raw['docdate']?.toString() ?? now,
        'deposit_type': raw['deposit_type']?.toString() ?? 'other',
        'amount': _parseDepositAmount(raw['amount']),
        'ref_party':
            raw['refparty']?.toString() ?? raw['ref_party']?.toString(),
        'party_name_snapshot': raw['party_name_snapshot']?.toString() ??
            raw['party_name']?.toString(),
        'contract_no': raw['contract_no']?.toString(),
        'detail': raw['detail']?.toString(),
        'due_date': raw['due_date']?.toString(),
        'ref_bank_account': raw['refbankaccount']?.toString() ??
            raw['ref_bank_account']?.toString(),
        'status': raw['status']?.toString() ?? 'holding',
        'settled_at': raw['settled_at']?.toString(),
        'settled_docno': raw['settled_docno']?.toString(),
        'settled_remark': raw['settled_remark']?.toString(),
        'fiscal_year': raw['fiscal_year']?.toString(),
        'ref_income_id': raw['ref_income_id']?.toString(),
        'ref_expense_id': raw['ref_expense_id']?.toString(),
        'income_docno': raw['income_docno']?.toString(),
        'expense_docno': raw['expense_docno']?.toString(),
        'synced': raw['synced'] is int
            ? raw['synced'] as int
            : (raw['synced'] == 0 || raw['synced'] == false ? 0 : 1),
        'last_modified': now,
        'updated': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  double _parseDepositAmount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '') ?? '') ?? 0;
  }

  Future<Map<String, dynamic>?> getDepositById(String id) async {
    await _ensureDb();
    final db = await _db.database;
    final rows = await db.query(
      'deposit_guarantee',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapDepositRow(rows.first);
  }

  Future<void> deleteDepositLocal(String id) async {
    await _ensureDb();
    final db = await _db.database;
    await db.delete('deposit_guarantee', where: 'id = ?', whereArgs: [id]);
  }

  /// รวมรายการจากเซิร์ฟเวอร์ลง SQLite (ใช้หลังดึง API / backup mirror)
  Future<void> mergeRemoteDeposits(
      List<Map<String, dynamic>> remoteRows) async {
    for (final row in remoteRows) {
      await upsertDepositFromServer(row);
    }
  }

  /// รายการ holding ใกล้ครบกำหนด / เลยกำหนด (อ่านจาก SQLite)
  Future<List<Map<String, dynamic>>> listDepositsDueSoon({
    int withinDays = 30,
    String? fiscalYear,
    String? depositType,
  }) async {
    await _ensureDb();
    final db = await _db.database;
    final end = DateTime.now().add(Duration(days: withinDays));
    final endIso = end.toIso8601String();

    final conditions = <String>[
      "status = 'holding'",
      'due_date IS NOT NULL',
      'due_date <= ?',
    ];
    final args = <Object?>[endIso];

    if (fiscalYear != null) {
      conditions.add('fiscal_year = ?');
      args.add(fiscalYear);
    }
    if (depositType != null && depositType.trim().isNotEmpty) {
      conditions.add('deposit_type = ?');
      args.add(depositType.trim());
    }

    final rows = await db.query(
      'deposit_guarantee',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'due_date ASC',
    );

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return rows.map((r) {
      final m = _mapDepositRow(r);
      final due = DateTime.tryParse(r['due_date']?.toString() ?? '');
      if (due != null) {
        final dueOnly = DateTime(due.year, due.month, due.day);
        final daysLeft = dueOnly.difference(todayOnly).inDays;
        m['days_left'] = daysLeft;
        m['is_overdue'] = daysLeft < 0;
      }
      return m;
    }).toList();
  }

  Future<Map<String, dynamic>> getDepositReconciliation({
    required String depositType,
  }) async {
    await _ensureDb();
    final db = await _db.database;
    final normalizedType =
        depositType.trim().isEmpty ? 'contract_guarantee' : depositType.trim();
    final expectedMoneyGroup = switch (normalizedType) {
      'contract_guarantee' => '4',
      'withholding_tax' => '3',
      _ => null,
    };
    if (expectedMoneyGroup == null) {
      return {
        'status': 'error',
        'message': 'รองรับเฉพาะเงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย',
      };
    }

    final holdingRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM deposit_guarantee
      WHERE deposit_type = ? AND status = 'holding'
    ''', [normalizedType]);
    final registerHolding = (holdingRows.first['total'] as num?)?.toDouble() ??
        double.tryParse(holdingRows.first['total']?.toString() ?? '0') ??
        0.0;

    final ledgerRows = await db.rawQuery('''
      SELECT
        COALESCE((
          SELECT SUM(CAST(s.amount AS REAL))
          FROM income i
          LEFT JOIN income_sub s ON s.refIncome = i.id
          INNER JOIN budget_source_budget bb ON bb.id = i.refBudgetSource
          INNER JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
          WHERE bm.refmoneygroup = ?
        ), 0) AS income_total,
        COALESCE((
          SELECT SUM(CAST(s.amount AS REAL))
          FROM expense e
          LEFT JOIN expense_sub s ON s.refExpense = e.id
          INNER JOIN budget_source_budget bb ON bb.id = e.refBudgetSource
          INNER JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
          WHERE bm.refmoneygroup = ?
        ), 0) AS expense_total
    ''', [expectedMoneyGroup, expectedMoneyGroup]);
    final ledger = ledgerRows.first;
    final incomeTotal = (ledger['income_total'] as num?)?.toDouble() ??
        double.tryParse(ledger['income_total']?.toString() ?? '0') ??
        0.0;
    final expenseTotal = (ledger['expense_total'] as num?)?.toDouble() ??
        double.tryParse(ledger['expense_total']?.toString() ?? '0') ??
        0.0;
    final ledgerNet = incomeTotal - expenseTotal;
    final diff = double.parse((registerHolding - ledgerNet).toStringAsFixed(2));

    return {
      'status': 'successfully',
      'data': {
        'deposit_type': normalizedType,
        'money_group_id': expectedMoneyGroup,
        'register_holding_total': registerHolding,
        'ledger_net_total': ledgerNet,
        'difference': diff,
        'balanced': diff.abs() < 0.01,
      },
    };
  }

  // ── 7. เบิกนอกงบประมาณ (off-budget ledger) ──────────────────────────

  /// ดึง off-budget ledger พร้อม opening, running balance, monthly summary
  Future<Map<String, dynamic>> getOffBudgetLedger({
    required int fiscalYearBuddhist,
    String? code,
  }) async {
    await _ensureDb();
    final db = await _db.database;

    // หา incometype จาก code
    final incomeTypeRows = await db.query(
      'income_type',
      where: code != null ? 'code = ?' : null,
      whereArgs: code != null ? [code] : null,
      limit: 1,
    );
    if (incomeTypeRows.isEmpty) {
      return <String, dynamic>{
        'error': 'ไม่พบหมวดเงิน',
        'requested': {'code': code},
      };
    }
    final incomeType = incomeTypeRows.first;
    final incomeTypeId = incomeType['id'];

    final (startDate, endDate) = _fyRange(fiscalYearBuddhist);
    final endDtFull = '${endDate.split('T')[0]} 23:59:59';

    // Query income + incomesub
    final incomes = await db.rawQuery('''
      SELECT
        i.id, i.docno, i.docdate, i.detail, i.remark,
        isub.amount, isub.refMoneyType,
        mt.name as money_type_name,
        bsm.name as budget_source_name
      FROM income i
      LEFT JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      LEFT JOIN budget_source_budget bsb ON i.refBudgetSource = bsb.id
      LEFT JOIN budget_source_master bsm ON bsb.refBudgetSourceMaster = bsm.id
      WHERE isub.refIncomeType = ?
        AND i.docdate >= ?
        AND i.docdate <= ?
      ORDER BY i.docdate ASC, i.id ASC
    ''', [incomeTypeId, startDate, endDtFull]);

    // Query expense + expensesub
    final expenses = await db.rawQuery('''
      SELECT
        e.id, e.docno, e.created as docdate, e.remark, e.detail as expense_detail,
        es.amount, es.refMoneyType,
        mt.name as money_type_name,
        bsm.name as budget_source_name
      FROM expense e
      LEFT JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      LEFT JOIN budget_source_budget bsb ON e.refBudgetSource = bsb.id
      LEFT JOIN budget_source_master bsm ON bsb.refBudgetSourceMaster = bsm.id
      WHERE es.refFundCategory = ?
        AND e.created >= ?
        AND e.created <= ?
      ORDER BY e.created ASC, e.id ASC
    ''', [incomeTypeId, startDate, endDtFull]);

    // Query opening balance (before startDate)
    final inBeforeRows = await db.rawQuery('''
      SELECT
        mt.name as mt_name,
        COALESCE(SUM(CAST(isub.amount AS REAL)), 0) as total
      FROM income i
      LEFT JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      WHERE isub.refIncomeType = ?
        AND i.docdate < ?
      GROUP BY mt.name
    ''', [incomeTypeId, startDate]);

    final outBeforeRows = await db.rawQuery('''
      SELECT
        mt.name as mt_name,
        COALESCE(SUM(CAST(es.amount AS REAL)), 0) as total
      FROM expense e
      LEFT JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      WHERE es.refFundCategory = ?
        AND e.created < ?
      GROUP BY mt.name
    ''', [incomeTypeId, startDate]);

    // Classify opening by pocket
    const pocketCash = 'cash';
    const pocketBank = 'bank';
    const pocketAgency = 'agency';

    final opening = <String, double>{
      pocketCash: 0.0,
      pocketBank: 0.0,
      pocketAgency: 0.0,
    };
    for (final r in inBeforeRows) {
      final pocket = PocketClassifier.pocketKey(r['mt_name']?.toString() ?? '');
      opening[pocket] = (opening[pocket] ?? 0.0) +
          (double.tryParse(r['total']?.toString() ?? '0') ?? 0.0);
    }
    for (final r in outBeforeRows) {
      final pocket = PocketClassifier.pocketKey(r['mt_name']?.toString() ?? '');
      opening[pocket] = (opening[pocket] ?? 0.0) -
          (double.tryParse(r['total']?.toString() ?? '0') ?? 0.0);
    }

    // Combine + sort events
    final events = <Map<String, dynamic>>[];
    for (final i in incomes) {
      if (sqliteMoneyIsBlankStringOrNull(i['amount'])) continue;
      events.add(<String, dynamic>{
        'kind': 'income',
        'entity_id': 'i_${i['id']}',
        'docdate': i['docdate'],
        'docno': i['docno'],
        'detail': i['detail'] ?? '',
        'remark': i['remark'] ?? '',
        'money_type_name': i['money_type_name'] ?? '',
        'pocket':
            PocketClassifier.pocketKey(i['money_type_name']?.toString() ?? ''),
        'budget_source_name': i['budget_source_name'] ?? '',
        'amount_in': double.tryParse(i['amount'].toString()) ?? 0.0,
        'amount_out': 0.0,
      });
    }
    for (final e in expenses) {
      if (sqliteMoneyIsBlankStringOrNull(e['amount'])) continue;
      final expDet = (e['expense_detail'] ?? '').toString().trim();
      final expRmk = (e['remark'] ?? '').toString().trim();
      final detailLine = expDet.isEmpty
          ? expRmk
          : expRmk.isEmpty
              ? expDet
              : '$expDet — $expRmk';
      events.add(<String, dynamic>{
        'kind': 'expense',
        'entity_id': 'e_${e['id']}',
        'docdate': e['docdate'],
        'docno': e['docno'],
        'detail': detailLine,
        'remark': e['remark'] ?? '',
        'money_type_name': e['money_type_name'] ?? '',
        'pocket':
            PocketClassifier.pocketKey(e['money_type_name']?.toString() ?? ''),
        'budget_source_name': e['budget_source_name'] ?? '',
        'amount_in': 0.0,
        'amount_out': double.tryParse(e['amount'].toString()) ?? 0.0,
      });
    }
    events.sort((a, b) {
      final da =
          DateTime.parse(a['docdate']?.toString() ?? '').millisecondsSinceEpoch;
      final dbMs =
          DateTime.parse(b['docdate']?.toString() ?? '').millisecondsSinceEpoch;
      if (da != dbMs) return da.compareTo(dbMs);
      final docCmp = (a['docno']?.toString() ?? '')
          .compareTo(b['docno']?.toString() ?? '');
      if (docCmp != 0) return docCmp;
      return (a['entity_id']?.toString() ?? '')
          .compareTo(b['entity_id']?.toString() ?? '');
    });

    // Calculate running balance + lines
    final running = Map<String, double>.from(opening);
    final lines = <Map<String, dynamic>>[];
    for (final ev in events) {
      final amtIn = (ev['amount_in'] as num).toDouble();
      final amtOut = (ev['amount_out'] as num).toDouble();
      final pocket = ev['pocket'] as String;
      if (amtIn > 0) running[pocket] = (running[pocket] ?? 0.0) + amtIn;
      if (amtOut > 0) running[pocket] = (running[pocket] ?? 0.0) - amtOut;
      final bc = running[pocketCash] ?? 0.0;
      final bb = running[pocketBank] ?? 0.0;
      final ba = running[pocketAgency] ?? 0.0;
      lines.add(<String, dynamic>{
        ...ev,
        'balance_cash': bc,
        'balance_bank': bb,
        'balance_agency': ba,
        'balance_total': bc + bb + ba,
      });
    }

    // Group by month (ต.ค. ปี-1 ถึง ก.ย. ปี)
    final ce = fiscalYearBuddhist - 543;
    final thaiMonthNames = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    final monthlyMap = <String, Map<String, dynamic>>{};
    for (final line in lines) {
      try {
        final dt = DateTime.parse(line['docdate']?.toString() ?? '');
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        monthlyMap[key] ??= <String, dynamic>{
          'in': 0.0,
          'out': 0.0,
          'by_pocket': <String, double>{
            pocketCash: 0.0,
            pocketBank: 0.0,
            pocketAgency: 0.0,
          },
        };
        final pocket = line['pocket'] as String;
        if ((line['amount_in'] as num).toDouble() > 0) {
          monthlyMap[key]!['in'] = (monthlyMap[key]!['in'] as num).toDouble() +
              (line['amount_in'] as num).toDouble();
          monthlyMap[key]!['by_pocket'][pocket] =
              (monthlyMap[key]!['by_pocket'][pocket] as num).toDouble() +
                  (line['amount_in'] as num).toDouble();
        } else {
          monthlyMap[key]!['out'] =
              (monthlyMap[key]!['out'] as num).toDouble() +
                  (line['amount_out'] as num).toDouble();
          monthlyMap[key]!['by_pocket'][pocket] =
              (monthlyMap[key]!['by_pocket'][pocket] as num).toDouble() -
                  (line['amount_out'] as num).toDouble();
        }
      } catch (e) {
        // skip invalid dates
      }
    }

    final months = <Map<String, dynamic>>[];
    for (int i = 0; i < 12; i++) {
      final m = (10 + i - 1) % 12;
      final y = i < 3 ? ce - 1 : ce;
      final key = '$y-${(m + 1).toString().padLeft(2, '0')}';
      final rec = monthlyMap[key] ??
          <String, dynamic>{
            'in': 0.0,
            'out': 0.0,
            'by_pocket': <String, double>{
              pocketCash: 0.0,
              pocketBank: 0.0,
              pocketAgency: 0.0,
            },
          };
      months.add(<String, dynamic>{
        'label': '${thaiMonthNames[m]} ${(y + 543).toString().substring(2)}',
        'year_be': y + 543,
        'month_index': m + 1,
        'total_in': rec['in'],
        'total_out': rec['out'],
        'cash': rec['by_pocket'][pocketCash] ?? 0.0,
        'bank': rec['by_pocket'][pocketBank] ?? 0.0,
        'agency': rec['by_pocket'][pocketAgency] ?? 0.0,
      });
    }

    final totalIn = lines.fold<double>(
        0.0, (s, l) => s + ((l['amount_in'] as num).toDouble()));
    final totalOut = lines.fold<double>(
        0.0, (s, l) => s + ((l['amount_out'] as num).toDouble()));

    return <String, dynamic>{
      'fiscal_year': fiscalYearBuddhist,
      'category': <String, dynamic>{
        'id': incomeType['id'],
        'code': incomeType['code'],
        'name': incomeType['name'],
      },
      'opening': opening,
      'lines': lines,
      'months': months,
      'total_in': totalIn,
      'total_out': totalOut,
      'ending': running,
    };
  }

  /// สรุปยอดรับ / จ่าย / คงเหลือสะสม แยกตามหมวดเงินนอกงบประมาณ (OB-01..OB-13)
  /// ในปีงบประมาณที่ระบุ — ใช้สำหรับตารางสรุปด้านบนของทะเบียนคุม
  Future<List<Map<String, dynamic>>> getOffBudgetCategorySummary({
    required int fiscalYearBuddhist,
  }) async {
    await _ensureDb();
    final db = await _db.database;
    final (startDate, endDate) = _fyRange(fiscalYearBuddhist);
    final endDtFull = '${endDate.split('T')[0]} 23:59:59';

    final types = await db.query(
      'income_type',
      where: "code LIKE 'OB-%'",
      orderBy: 'CAST(sort AS INTEGER) ASC, code ASC',
    );
    if (types.isEmpty) return const [];

    final ids =
        types.map((e) => e['id']?.toString()).whereType<String>().toList();
    if (ids.isEmpty) return const [];
    final ph = List.filled(ids.length, '?').join(',');

    Future<List<Map<String, Object?>>> groupedOpeningIncome() => db.rawQuery('''
      SELECT isub.refIncomeType AS tid, mt.name AS mt_name,
             SUM(CAST(isub.amount AS REAL)) AS total
      FROM income i
      INNER JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      WHERE isub.refIncomeType IN ($ph) AND i.docdate < ?
      GROUP BY isub.refIncomeType, mt.name
    ''', [...ids, startDate]);

    Future<List<Map<String, Object?>>> groupedOpeningExpense() =>
        db.rawQuery('''
      SELECT es.refFundCategory AS tid, mt.name AS mt_name,
             SUM(CAST(es.amount AS REAL)) AS total
      FROM expense e
      INNER JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      WHERE es.refFundCategory IN ($ph) AND e.created < ?
      GROUP BY es.refFundCategory, mt.name
    ''', [...ids, startDate]);

    Future<List<Map<String, Object?>>> fyIncomeTotals() => db.rawQuery('''
      SELECT isub.refIncomeType AS tid,
             SUM(CAST(isub.amount AS REAL)) AS total
      FROM income i
      INNER JOIN income_sub isub ON i.id = isub.refIncome
      WHERE isub.refIncomeType IN ($ph)
        AND i.docdate >= ? AND i.docdate <= ?
      GROUP BY isub.refIncomeType
    ''', [...ids, startDate, endDtFull]);

    Future<List<Map<String, Object?>>> fyExpenseTotals() => db.rawQuery('''
      SELECT es.refFundCategory AS tid,
             SUM(CAST(es.amount AS REAL)) AS total
      FROM expense e
      INNER JOIN expense_sub es ON e.id = es.refExpense
      WHERE es.refFundCategory IN ($ph)
        AND e.created >= ? AND e.created <= ?
      GROUP BY es.refFundCategory
    ''', [...ids, startDate, endDtFull]);

    final openInRows = await groupedOpeningIncome();
    final openOutRows = await groupedOpeningExpense();
    final fyInRows = await fyIncomeTotals();
    final fyOutRows = await fyExpenseTotals();

    final openingByTid = <String, Map<String, double>>{};
    void bumpPocket(String tid, String pocket, double delta) {
      final m = openingByTid.putIfAbsent(
        tid,
        () => {
          PocketClassifier.pocketCash: 0.0,
          PocketClassifier.pocketBank: 0.0,
          PocketClassifier.pocketAgency: 0.0,
        },
      );
      m[pocket] = (m[pocket] ?? 0.0) + delta;
    }

    for (final r in openInRows) {
      final tid = r['tid']?.toString();
      if (tid == null) continue;
      final pocket = PocketClassifier.pocketKey(r['mt_name']?.toString() ?? '');
      final v = double.tryParse(r['total']?.toString() ?? '0') ?? 0.0;
      bumpPocket(tid, pocket, v);
    }
    for (final r in openOutRows) {
      final tid = r['tid']?.toString();
      if (tid == null) continue;
      final pocket = PocketClassifier.pocketKey(r['mt_name']?.toString() ?? '');
      final v = double.tryParse(r['total']?.toString() ?? '0') ?? 0.0;
      bumpPocket(tid, pocket, -v);
    }

    final fyIn = <String, double>{};
    for (final r in fyInRows) {
      final tid = r['tid']?.toString();
      if (tid == null) continue;
      fyIn[tid] = double.tryParse(r['total']?.toString() ?? '0') ?? 0.0;
    }
    final fyOut = <String, double>{};
    for (final r in fyOutRows) {
      final tid = r['tid']?.toString();
      if (tid == null) continue;
      fyOut[tid] = double.tryParse(r['total']?.toString() ?? '0') ?? 0.0;
    }

    double sumPockets(Map<String, double>? m) {
      if (m == null) return 0.0;
      return (m[PocketClassifier.pocketCash] ?? 0.0) +
          (m[PocketClassifier.pocketBank] ?? 0.0) +
          (m[PocketClassifier.pocketAgency] ?? 0.0);
    }

    final out = <Map<String, dynamic>>[];
    for (final t in types) {
      final tid = t['id']?.toString();
      if (tid == null) continue;
      final open = openingByTid[tid];
      final openSum = sumPockets(open);
      final tin = fyIn[tid] ?? 0.0;
      final tout = fyOut[tid] ?? 0.0;
      final running = openSum + tin - tout;
      out.add(<String, dynamic>{
        'code': t['code'],
        'name': t['name'],
        'opening_total': openSum,
        'total_in': tin,
        'total_out': tout,
        'running_balance': running,
        'opening_cash': open?[PocketClassifier.pocketCash] ?? 0.0,
        'opening_bank': open?[PocketClassifier.pocketBank] ?? 0.0,
        'opening_agency': open?[PocketClassifier.pocketAgency] ?? 0.0,
      });
    }
    return out;
  }

  // ── 8. ทะเบียนคุมเงินฝากธนาคาร ประเภทกระแสรายวัน ────────
  //
  // คอลัมน์: วัน เดือน ปี | ที่เอกสาร | รายการ | ฝาก | ถอน | คงเหลือ | หมายเหตุ
  // - "ฝาก" = income ที่ pocket=bank
  // - "ถอน" = expense ที่ pocket=bank
  // - คงเหลือเรียงตามเวลาในปีงบประมาณ
  Future<Map<String, dynamic>> getCurrentAccountRegister({
    required int fiscalYearBuddhist,
  }) async {
    await _ensureDb();
    final db = await _db.database;
    final (start, end) = _fyRange(fiscalYearBuddhist);

    // Opening balance ก่อนปีงบฯ
    final openIn = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(isub.amount AS REAL)), 0) AS total
      FROM income i
      LEFT JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      WHERE i.docdate < ?
        AND (
          LOWER(IFNULL(mt.name,'')) LIKE '%ฝาก%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%ธนาคาร%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%bank%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%โอน%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%เช็ค%'
        )
        AND LOWER(IFNULL(mt.name,'')) NOT LIKE '%ส่วนราชการ%'
    ''', [start]);

    final openOut = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(es.amount AS REAL)), 0) AS total
      FROM expense e
      LEFT JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      WHERE e.created < ?
        AND (
          LOWER(IFNULL(mt.name,'')) LIKE '%ฝาก%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%ธนาคาร%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%bank%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%โอน%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%เช็ค%'
        )
        AND LOWER(IFNULL(mt.name,'')) NOT LIKE '%ส่วนราชการ%'
    ''', [start]);

    final opening = ((openIn.first['total'] as num?)?.toDouble() ?? 0) -
        ((openOut.first['total'] as num?)?.toDouble() ?? 0);

    // Income (ฝาก) ในช่วงปีงบฯ
    final incomes = await db.rawQuery('''
      SELECT i.docdate, i.docno, i.detail, i.remark,
             isub.amount, mt.name AS mt_name
      FROM income i
      LEFT JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      WHERE i.docdate >= ? AND i.docdate <= ?
      ORDER BY i.docdate ASC, i.id ASC
    ''', [start, end]);

    // Expense (ถอน) ในช่วงปีงบฯ
    final expenses = await db.rawQuery('''
      SELECT e.created AS docdate, e.docno, e.detail, e.remark,
             es.amount, mt.name AS mt_name
      FROM expense e
      LEFT JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      WHERE e.created >= ? AND e.created <= ?
      ORDER BY e.created ASC, e.id ASC
    ''', [start, end]);

    final lines = <Map<String, dynamic>>[];
    double running = opening;

    void addLine(Map<String, Object?> r, {required bool isIn}) {
      final pocket = PocketClassifier.pocketKey(r['mt_name']?.toString());
      if (pocket != 'bank') return;
      final amt = double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
      if (amt <= 0) return;
      if (isIn) {
        running += amt;
      } else {
        running -= amt;
      }
      lines.add({
        'docdate': r['docdate'],
        'docno': r['docno'] ?? '-',
        'detail': r['detail'] ?? r['remark'] ?? '',
        'deposit': isIn ? amt : 0.0,
        'withdraw': isIn ? 0.0 : amt,
        'balance': running,
        'remark': r['remark'] ?? '',
      });
    }

    final all = <Map<String, Object?>>[];
    for (final r in incomes) {
      all.add({...r, '_kind': 'in'});
    }
    for (final r in expenses) {
      all.add({...r, '_kind': 'out'});
    }
    all.sort((a, b) {
      final da =
          DateTime.tryParse(a['docdate']?.toString() ?? '') ?? DateTime(1900);
      final bDt =
          DateTime.tryParse(b['docdate']?.toString() ?? '') ?? DateTime(1900);
      return da.compareTo(bDt);
    });
    for (final r in all) {
      addLine(r, isIn: r['_kind'] == 'in');
    }

    return <String, dynamic>{
      'fiscal_year': fiscalYearBuddhist,
      'opening': opening,
      'lines': lines,
      'ending': running,
    };
  }

  // ── 9. สมุดคู่ฝาก (ส่วนราชการผู้เบิก) ─────────────────
  //
  // คอลัมน์: วัน เดือน ปี | ที่เอกสาร | ฝาก | ถอน | คงเหลือ | ผู้รับฝาก/นำฝาก | หมายเหตุ
  // กรองเฉพาะรายการที่ pocket=agency (เงินฝากส่วนราชการผู้เบิก)
  Future<Map<String, dynamic>> getAgencyDepositRegister({
    required int fiscalYearBuddhist,
  }) async {
    await _ensureDb();
    final db = await _db.database;
    final (start, end) = _fyRange(fiscalYearBuddhist);

    final openIn = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(isub.amount AS REAL)), 0) AS total
      FROM income i
      LEFT JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      WHERE i.docdate < ?
        AND (
          LOWER(IFNULL(mt.name,'')) LIKE '%ส่วนราชการ%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%agency%'
        )
    ''', [start]);

    final openOut = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(es.amount AS REAL)), 0) AS total
      FROM expense e
      LEFT JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      WHERE e.created < ?
        AND (
          LOWER(IFNULL(mt.name,'')) LIKE '%ส่วนราชการ%' OR
          LOWER(IFNULL(mt.name,'')) LIKE '%agency%'
        )
    ''', [start]);

    final opening = ((openIn.first['total'] as num?)?.toDouble() ?? 0) -
        ((openOut.first['total'] as num?)?.toDouble() ?? 0);

    final incomes = await db.rawQuery('''
      SELECT i.docdate, i.docno, i.detail, i.remark, i.partyName,
             isub.amount, mt.name AS mt_name
      FROM income i
      LEFT JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      WHERE i.docdate >= ? AND i.docdate <= ?
      ORDER BY i.docdate ASC, i.id ASC
    ''', [start, end]);

    final expenses = await db.rawQuery('''
      SELECT e.created AS docdate, e.docno, e.detail, e.remark, e.partyName,
             es.amount, mt.name AS mt_name
      FROM expense e
      LEFT JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      WHERE e.created >= ? AND e.created <= ?
      ORDER BY e.created ASC, e.id ASC
    ''', [start, end]);

    final lines = <Map<String, dynamic>>[];
    double running = opening;

    void addLine(Map<String, Object?> r, {required bool isIn}) {
      final pocket = PocketClassifier.pocketKey(r['mt_name']?.toString());
      if (pocket != 'agency') return;
      final amt = double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
      if (amt <= 0) return;
      if (isIn) {
        running += amt;
      } else {
        running -= amt;
      }
      lines.add({
        'docdate': r['docdate'],
        'docno': r['docno'] ?? '-',
        'deposit': isIn ? amt : 0.0,
        'withdraw': isIn ? 0.0 : amt,
        'balance': running,
        'party_name': r['partyName'] ?? '-',
        'remark': r['detail'] ?? r['remark'] ?? '',
      });
    }

    final all = <Map<String, Object?>>[];
    for (final r in incomes) {
      all.add({...r, '_kind': 'in'});
    }
    for (final r in expenses) {
      all.add({...r, '_kind': 'out'});
    }
    all.sort((a, b) {
      final da =
          DateTime.tryParse(a['docdate']?.toString() ?? '') ?? DateTime(1900);
      final bDt =
          DateTime.tryParse(b['docdate']?.toString() ?? '') ?? DateTime(1900);
      return da.compareTo(bDt);
    });
    for (final r in all) {
      addLine(r, isIn: r['_kind'] == 'in');
    }

    return <String, dynamic>{
      'fiscal_year': fiscalYearBuddhist,
      'opening': opening,
      'lines': lines,
      'ending': running,
    };
  }

  // ── 10. ทะเบียนคุมรับและนำส่งเงินรายได้แผ่นดิน ─────────
  //
  // กรองเฉพาะ income ที่ผูกกับ moneygroup "เงินรายได้แผ่นดิน"
  // (ผ่าน budget_source_master.refmoneygroup → money_group.name หรือ
  //  income_type.code ที่ระบุเป็นรายได้แผ่นดิน)
  // คอลัมน์: วัน | ที่เอกสาร | รายการ | รับ | นำส่ง | คงเหลือ | หมายเหตุ
  Future<Map<String, dynamic>> getTreasuryRemitRegister({
    required int fiscalYearBuddhist,
  }) async {
    await _ensureDb();
    final db = await _db.database;
    final (start, end) = _fyRange(fiscalYearBuddhist);

    // หา money_group id ของ "เงินรายได้แผ่นดิน"
    String? treasuryGroupId;
    try {
      final mg = await db.query(
        'money_group',
        where: "name LIKE ? OR name LIKE ?",
        whereArgs: ['%รายได้แผ่นดิน%', '%treasury%'],
        limit: 1,
      );
      if (mg.isNotEmpty) {
        treasuryGroupId = mg.first['id']?.toString();
      }
    } catch (_) {}

    if (treasuryGroupId == null) {
      return <String, dynamic>{
        'fiscal_year': fiscalYearBuddhist,
        'opening': 0.0,
        'lines': const <Map<String, dynamic>>[],
        'ending': 0.0,
        'note': TransactionUiText.registerTreasuryRemitNoMoneyGroupNote,
      };
    }

    // รายการรับเงิน (income) ที่ผ่านแหล่งเงินที่อ้าง money_group นี้
    // หรือ fallback จาก income_type ที่ชี้ไป money_group เดียวกัน/รหัสรายได้แผ่นดิน
    final incomes = await db.rawQuery('''
      SELECT i.docdate, i.docno, i.detail, i.remark, i.partyName,
             isub.amount, mt.name AS mt_name,
             bsm.name AS budget_source_name
      FROM income i
      LEFT JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN income_type it ON it.id = isub.refIncomeType
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      LEFT JOIN budget_source_budget bsb ON i.refBudgetSource = bsb.id
      LEFT JOIN budget_source_master bsm
        ON bsb.refBudgetSourceMaster = bsm.id
      WHERE (
          bsm.refmoneygroup = ?
          OR it.refMoneyGroup = ?
          OR LOWER(IFNULL(it.name, '')) LIKE '%รายได้แผ่นดิน%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'TR-%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'REV-%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'TI-%'
      )
        AND i.docdate >= ? AND i.docdate <= ?
      ORDER BY i.docdate ASC, i.id ASC
    ''', [treasuryGroupId, treasuryGroupId, start, end]);

    // รายการนำส่ง (expense) — ใช้ remark/detail ที่ระบุ "นำส่งคลัง"
    // หรือทุก expense จากแหล่งเดียวกันถือเป็นการนำส่ง
    final remits = await db.rawQuery('''
      SELECT e.created AS docdate, e.docno, e.detail, e.remark,
             es.amount, mt.name AS mt_name,
             bsm.name AS budget_source_name
      FROM expense e
      LEFT JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN income_type it ON it.id = es.refFundCategory
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      LEFT JOIN budget_source_budget bsb ON e.refBudgetSource = bsb.id
      LEFT JOIN budget_source_master bsm
        ON bsb.refBudgetSourceMaster = bsm.id
      WHERE (
          bsm.refmoneygroup = ?
          OR it.refMoneyGroup = ?
          OR LOWER(IFNULL(it.name, '')) LIKE '%รายได้แผ่นดิน%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'TR-%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'REV-%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'TI-%'
      )
        AND e.created >= ? AND e.created <= ?
      ORDER BY e.created ASC, e.id ASC
    ''', [treasuryGroupId, treasuryGroupId, start, end]);

    // Opening balance ก่อนปีงบฯ
    final openIn = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(isub.amount AS REAL)), 0) AS total
      FROM income i
      LEFT JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN income_type it ON it.id = isub.refIncomeType
      LEFT JOIN budget_source_budget bsb ON i.refBudgetSource = bsb.id
      LEFT JOIN budget_source_master bsm
        ON bsb.refBudgetSourceMaster = bsm.id
      WHERE (
          bsm.refmoneygroup = ?
          OR it.refMoneyGroup = ?
          OR LOWER(IFNULL(it.name, '')) LIKE '%รายได้แผ่นดิน%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'TR-%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'REV-%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'TI-%'
      ) AND i.docdate < ?
    ''', [treasuryGroupId, treasuryGroupId, start]);

    final openOut = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(es.amount AS REAL)), 0) AS total
      FROM expense e
      LEFT JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN income_type it ON it.id = es.refFundCategory
      LEFT JOIN budget_source_budget bsb ON e.refBudgetSource = bsb.id
      LEFT JOIN budget_source_master bsm
        ON bsb.refBudgetSourceMaster = bsm.id
      WHERE (
          bsm.refmoneygroup = ?
          OR it.refMoneyGroup = ?
          OR LOWER(IFNULL(it.name, '')) LIKE '%รายได้แผ่นดิน%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'TR-%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'REV-%'
          OR UPPER(IFNULL(it.code, '')) LIKE 'TI-%'
      ) AND e.created < ?
    ''', [treasuryGroupId, treasuryGroupId, start]);

    final opening = ((openIn.first['total'] as num?)?.toDouble() ?? 0) -
        ((openOut.first['total'] as num?)?.toDouble() ?? 0);

    final lines = <Map<String, dynamic>>[];
    double running = opening;

    void addLine(Map<String, Object?> r, {required bool isIn}) {
      final amt = double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
      if (amt <= 0) return;
      if (isIn) {
        running += amt;
      } else {
        running -= amt;
      }
      lines.add({
        'docdate': r['docdate'],
        'docno': r['docno'] ?? '-',
        'detail': r['detail'] ?? r['remark'] ?? '',
        'budget_source_name': r['budget_source_name'] ?? '-',
        'received': isIn ? amt : 0.0,
        'remitted': isIn ? 0.0 : amt,
        'balance': running,
        'remark': r['remark'] ?? '',
      });
    }

    final all = <Map<String, Object?>>[];
    for (final r in incomes) {
      all.add({...r, '_kind': 'in'});
    }
    for (final r in remits) {
      all.add({...r, '_kind': 'out'});
    }
    all.sort((a, b) {
      final da =
          DateTime.tryParse(a['docdate']?.toString() ?? '') ?? DateTime(1900);
      final bDt =
          DateTime.tryParse(b['docdate']?.toString() ?? '') ?? DateTime(1900);
      return da.compareTo(bDt);
    });
    for (final r in all) {
      addLine(r, isIn: r['_kind'] == 'in');
    }

    return <String, dynamic>{
      'fiscal_year': fiscalYearBuddhist,
      'opening': opening,
      'lines': lines,
      'ending': running,
    };
  }
}
