import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/utils/pocket_classifier.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/features/reports/data/daily_balance_local_computer.dart';
import 'package:sqflite/sqflite.dart';

class ReportsLocalDataSource {
  ReportsLocalDataSource({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase();

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  Future<Map<String, dynamic>> loadBundle(String fiscalYear) async {
    final db = await _db;
    final fy = int.tryParse(fiscalYear) ?? DateTime.now().year + 543;
    final ce = fy - 543;
    final start = '${ce - 1}-10-01';
    final end = '$ce-09-30';

    Future<double> scalarSum(String sql, List<Object?> args) async {
      final rows = await db.rawQuery(sql, args);
      if (rows.isEmpty) return 0;
      return double.tryParse(rows.first.values.first?.toString() ?? '0') ?? 0;
    }

    final totalIncome = await scalarSum(
      "SELECT COALESCE(SUM(CAST(amount AS REAL)),0) FROM income WHERE substr(docdate,1,10) BETWEEN ? AND ?",
      [start, end],
    );
    final totalExpense = await scalarSum(
      "SELECT COALESCE(SUM(CAST(amount AS REAL)),0) FROM expense WHERE substr(COALESCE(docdate, created),1,10) BETWEEN ? AND ?",
      [start, end],
    );
    final totalLoan = await scalarSum(
      "SELECT COALESCE(SUM(CAST(amount AS REAL) + CAST(opening_outstanding AS REAL)),0) FROM loan WHERE substr(loandate,1,10) BETWEEN ? AND ?",
      [start, end],
    );
    final totalRepay = await scalarSum(
      "SELECT COALESCE(SUM(CAST(amount AS REAL)),0) FROM repay_loan WHERE substr(created,1,10) BETWEEN ? AND ?",
      [start, end],
    );

    final incomeByMonth = await db.rawQuery('''
      SELECT substr(docdate, 1, 7) AS month, COALESCE(SUM(CAST(amount AS REAL)),0) AS total
      FROM income
      WHERE substr(docdate,1,10) BETWEEN ? AND ?
      GROUP BY substr(docdate, 1, 7)
      ORDER BY month ASC
    ''', [start, end]);
    final expenseByMonth = await db.rawQuery('''
      SELECT substr(COALESCE(docdate, created), 1, 7) AS month, COALESCE(SUM(CAST(amount AS REAL)),0) AS total
      FROM expense
      WHERE substr(COALESCE(docdate, created),1,10) BETWEEN ? AND ?
      GROUP BY substr(COALESCE(docdate, created), 1, 7)
      ORDER BY month ASC
    ''', [start, end]);

    final budgetData = await db.rawQuery('''
      SELECT
        bsm.code,
        bsm.name,
        COALESCE(SUM(bsb.budget_amount),0) AS budget_amount,
        COALESCE(SUM(bsb.brought_forward_amount),0) AS brought_forward_amount,
        COALESCE(SUM(bsb.used_amount),0) AS used_expense,
        COALESCE(SUM(bsb.used_amount),0) AS used_amount,
        COALESCE(SUM(inc.income_amount),0) AS income_amount,
        COALESCE(SUM(bsb.budget_amount + bsb.brought_forward_amount - bsb.used_amount),0) AS remaining,
        CASE
          WHEN COALESCE(SUM(bsb.budget_amount + bsb.brought_forward_amount),0) > 0
          THEN ROUND(
            COALESCE(SUM(bsb.used_amount),0) * 100.0 /
            COALESCE(SUM(bsb.budget_amount + bsb.brought_forward_amount),0),
            2
          )
          ELSE 0
        END AS used_percent
      FROM budget_source_master bsm
      LEFT JOIN budget_source_budget bsb ON bsb.refBudgetSourceMaster = bsm.id
      LEFT JOIN (
        SELECT refBudgetSource, COALESCE(SUM(CAST(amount AS REAL)),0) AS income_amount
        FROM income
        WHERE substr(docdate,1,10) BETWEEN ? AND ?
        GROUP BY refBudgetSource
      ) inc ON inc.refBudgetSource = bsb.id
      WHERE bsb.fiscal_year = ?
      GROUP BY bsm.id, bsm.code, bsm.name
      ORDER BY bsm.code ASC
    ''', [start, end, fiscalYear]);

    final trialIncome = await db.rawQuery('''
      SELECT COALESCE(mt.name, 'ไม่ระบุ') AS type_name,
             COALESCE(SUM(CAST(isub.amount AS REAL)),0) AS total,
             COUNT(DISTINCT i.id) AS count
      FROM income i
      INNER JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON mt.id = COALESCE(isub.refMoneyType, i.refMoneyType)
      WHERE substr(i.docdate,1,10) BETWEEN ? AND ?
      GROUP BY mt.id, mt.name
      ORDER BY total DESC
    ''', [start, end]);
    final trialExpense = await db.rawQuery('''
      SELECT COALESCE(mt.name, 'ไม่ระบุ') AS type_name,
             COALESCE(SUM(CAST(es.amount AS REAL)),0) AS total,
             COUNT(DISTINCT e.id) AS count
      FROM expense e
      INNER JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON mt.id = es.refMoneyType
      WHERE substr(COALESCE(e.docdate, e.created),1,10) BETWEEN ? AND ?
      GROUP BY mt.id, mt.name
      ORDER BY total DESC
    ''', [start, end]);

    final annualSummary = await loadAnnualSummary(fiscalYear);

    return {
      'summary': {
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'balance': totalIncome - totalExpense,
        'total_loan': totalLoan,
        'total_repay': totalRepay,
        'source': 'local',
      },
      'incomeByMonth': incomeByMonth,
      'expenseByMonth': expenseByMonth,
      'budgetData': budgetData,
      'trialBalance': {
        'income': trialIncome,
        'expense': trialExpense,
        'source': 'local',
      },
      'budgetRemaining': budgetData,
      'annualSummary': annualSummary,
    };
  }

  Future<Map<String, dynamic>> loadAnnualSummary(String fiscalYear) async {
    final db = await _db;
    final fy = int.tryParse(fiscalYear) ?? DateTime.now().year + 543;
    final adYear = fy - 543;
    final start = '${adYear - 1}-10-01';
    final end = '$adYear-09-30';

    final income = await db.rawQuery('''
      SELECT it.code, it.name AS type_name,
             COALESCE(SUM(CAST(isub.amount AS REAL)),0) AS total,
             COUNT(DISTINCT i.id) AS count
      FROM income i
      INNER JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN income_type it ON it.id = isub.refIncomeType
      WHERE substr(i.docdate,1,10) BETWEEN ? AND ?
      GROUP BY it.code, it.name, it.sort
      ORDER BY it.sort ASC
    ''', [start, end]);

    final expenseDetails = await db.rawQuery('''
      SELECT et.code, et.name AS type_name,
             COALESCE(SUM(CAST(es.amount AS REAL)),0) AS total,
             COUNT(DISTINCT e.id) AS count
      FROM expense e
      INNER JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN expense_type et ON et.id = es.refExpenseType
      WHERE substr(COALESCE(e.docdate, e.created),1,10) BETWEEN ? AND ?
      GROUP BY et.code, et.name, et.sort
      ORDER BY et.sort ASC
    ''', [start, end]);

    final totalIncome =
        income.fold<double>(0, (sum, row) => sum + _d(row['total']));
    final totalExpense =
        expenseDetails.fold<double>(0, (sum, row) => sum + _d(row['total']));

    return {
      'fiscal_year': fiscalYear,
      'income': income,
      'expense': groupExpenseRowsByOfficialSection(expenseDetails),
      'expense_details': expenseDetails,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'balance': totalIncome - totalExpense,
      'source': 'local',
    };
  }

  Future<Map<String, dynamic>> loadDailyBalance(String date) async {
    final db = await _db;
    return DailyBalanceLocalComputer().compute(db, date);
  }

  Future<Map<String, dynamic>> loadBankReconciliation(String date) async {
    final db = await _db;
    final day =
        date.trim().length >= 10 ? date.trim().substring(0, 10) : date.trim();

    final accounts = await db.rawQuery('''
      SELECT
        ba.id,
        ba.accountnumber,
        ba.accountname,
        ba.opening_balance,
        b.name AS bank_name
      FROM bank_account ba
      LEFT JOIN bank b ON b.id = ba.refBank
      WHERE ba.use IS NULL OR ba.use = 'Y'
      ORDER BY ba.sort ASC, ba.id ASC
    ''');

    final incomeRows = await db.rawQuery('''
      SELECT
        isub.amount AS amount,
        mt.name AS mt_name,
        COALESCE(i.refBankAccount, bsm.refBankAccount, it.refBankAccount) AS bank_slot
      FROM income i
      INNER JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON mt.id = isub.refMoneyType
      LEFT JOIN budget_source_budget bsb ON bsb.id = i.refBudgetSource
      LEFT JOIN budget_source_master bsm ON bsm.id = bsb.refBudgetSourceMaster
      LEFT JOIN income_type it ON it.id = isub.refIncomeType
      WHERE substr(i.docdate, 1, 10) <= ?
    ''', [day]);
    final expenseRows = await db.rawQuery('''
      SELECT
        es.amount AS amount,
        mt.name AS mt_name,
        COALESCE(e.refBankAccount, bsm.refBankAccount, it.refBankAccount) AS bank_slot
      FROM expense e
      INNER JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON mt.id = es.refMoneyType
      LEFT JOIN budget_source_budget bsb ON bsb.id = e.refBudgetSource
      LEFT JOIN budget_source_master bsm ON bsm.id = bsb.refBudgetSourceMaster
      LEFT JOIN income_type it ON it.id = es.refFundCategory
      WHERE substr(COALESCE(e.docdate, e.created), 1, 10) <= ?
    ''', [day]);

    final inByAccount = <String, double>{};
    final outByAccount = <String, double>{};
    for (final row in incomeRows) {
      _addBankMovement(inByAccount, row);
    }
    for (final row in expenseRows) {
      _addBankMovement(outByAccount, row);
    }

    final chequeRows = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(pc.chequeamount AS REAL)), 0) AS total
      FROM pay_cheque pc
      LEFT JOIN expense e ON e.id = pc.refExpense
      WHERE substr(COALESCE(e.docdate, e.created), 1, 10) <= ?
        AND (pc.cleared_at IS NULL OR TRIM(pc.cleared_at) = '')
    ''', [day]);
    final outstandingChequeTotal = _d(
      chequeRows.isEmpty ? null : chequeRows.first['total'],
    );

    var totalOpening = 0.0;
    var totalIn = 0.0;
    var totalOut = 0.0;
    final accountRows = <Map<String, dynamic>>[];
    for (final account in accounts) {
      final id = account['id']?.toString() ?? '';
      final opening = _d(account['opening_balance']);
      final tin = inByAccount[id] ?? 0;
      final tout = outByAccount[id] ?? 0;
      totalOpening += opening;
      totalIn += tin;
      totalOut += tout;
      accountRows.add({
        ...Map<String, dynamic>.from(account),
        'total_in_bank': tin,
        'total_out_bank': tout,
        'book_balance': opening + tin - tout,
      });
    }

    final unallocatedIn = inByAccount['__null__'] ?? 0;
    final unallocatedOut = outByAccount['__null__'] ?? 0;
    totalIn += unallocatedIn;
    totalOut += unallocatedOut;
    final bookBalance = totalOpening + totalIn - totalOut;
    final adjustmentNotes = await db.query(
      'bank_reconciliation_adjustment',
      where: 'as_of_date = ?',
      whereArgs: [day],
      orderBy: 'id DESC',
    );

    return {
      'as_of': day,
      'accounts': accountRows,
      'unallocated_bank_movements': {
        'total_in_bank': unallocatedIn,
        'total_out_bank': unallocatedOut,
        'net_movement': unallocatedIn - unallocatedOut,
      },
      'total_opening': totalOpening,
      'total_in_bank': totalIn,
      'total_out_bank': totalOut,
      'book_balance': bookBalance,
      'outstanding_cheque_total': outstandingChequeTotal,
      'reconciled_statement_balance': bookBalance + outstandingChequeTotal,
      'adjustment_policy': 'notes_only',
      'adjustment_notes': adjustmentNotes,
      'source': 'local',
    };
  }

  Future<Map<String, dynamic>> loadOutstandingCheques({
    required String date,
    int? fiscalYear,
  }) async {
    final local = RegisterLocalDataSource();
    final allRows = await local.getOutstandingCheques(fiscalYear: fiscalYear);
    final asOf =
        date.trim().length >= 10 ? date.trim().substring(0, 10) : date.trim();
    final rows = allRows.where((r) {
      final raw = r['docdate']?.toString() ?? '';
      if (raw.isEmpty) return true;
      final day = raw.length >= 10 ? raw.substring(0, 10) : raw;
      return day.compareTo(asOf) <= 0;
    }).toList();

    final normalized = rows.map((r) {
      final row = Map<String, dynamic>.from(r);
      if (row['amount'] == null && row['chequeamount'] != null) {
        row['amount'] = row['chequeamount'];
      }
      return row;
    }).toList();
    final total = normalized.fold<double>(
      0,
      (sum, row) => sum + _d(row['amount'] ?? row['chequeamount']),
    );

    return {
      'as_of': asOf,
      'fiscal_year': fiscalYear,
      'rows': normalized,
      'total_outstanding': total,
      'count': normalized.length,
      'source': 'local',
    };
  }

  Future<Map<String, dynamic>> loadDailyCashSummary(String isoDate) async {
    final db = await _db;
    final day = isoDate.trim().length >= 10
        ? isoDate.trim().substring(0, 10)
        : isoDate.trim();

    Future<double> sumIncomeCashBefore() async {
      final rows = await db.rawQuery('''
        SELECT isub.amount AS amount, mt.name AS mt_name
        FROM income i
        INNER JOIN income_sub isub ON i.id = isub.refIncome
        LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
        WHERE substr(i.docdate, 1, 10) < ?
      ''', [day]);
      return _sumRowsForPocket(rows, PocketClassifier.pocketCash);
    }

    Future<double> sumExpenseCashBefore() async {
      final rows = await db.rawQuery('''
        SELECT es.amount AS amount, mt.name AS mt_name
        FROM expense e
        INNER JOIN expense_sub es ON e.id = es.refExpense
        LEFT JOIN money_type mt ON es.refMoneyType = mt.id
        WHERE substr(COALESCE(e.docdate, e.created), 1, 10) < ?
      ''', [day]);
      return _sumRowsForPocket(rows, PocketClassifier.pocketCash);
    }

    Future<double> sumIncomeOnDay(String pocket) async {
      final rows = await db.rawQuery('''
        SELECT isub.amount AS amount, mt.name AS mt_name
        FROM income i
        INNER JOIN income_sub isub ON i.id = isub.refIncome
        LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
        WHERE substr(i.docdate, 1, 10) = ?
      ''', [day]);
      return _sumRowsForPocket(rows, pocket);
    }

    Future<double> sumExpenseCashOnDay() async {
      final rows = await db.rawQuery('''
        SELECT es.amount AS amount, mt.name AS mt_name
        FROM expense e
        INNER JOIN expense_sub es ON e.id = es.refExpense
        LEFT JOIN money_type mt ON es.refMoneyType = mt.id
        WHERE substr(COALESCE(e.docdate, e.created), 1, 10) = ?
      ''', [day]);
      return _sumRowsForPocket(rows, PocketClassifier.pocketCash);
    }

    final opening = await sumIncomeCashBefore() - await sumExpenseCashBefore();
    final inCash = await sumIncomeOnDay(PocketClassifier.pocketCash);
    final inTransfer = await sumIncomeOnDay(PocketClassifier.pocketBank);
    final paidCash = await sumExpenseCashOnDay();
    final closing = opening + inCash - paidCash;

    return <String, dynamic>{
      'date': day,
      'opening_cash': opening,
      'received_cash_today': inCash,
      'received_transfer_today': inTransfer,
      'paid_cash_today': paidCash,
      'closing_cash': closing,
      'source': 'local',
    };
  }

  static Map<String, dynamic> expenseReportGroupForCode(String? code) {
    final normalized = (code ?? '').padLeft(2, '0');
    if (normalized == '00') {
      return {'code': 'personnel', 'type_name': 'งบบุคลากร', 'sort': 1};
    }
    if (['01', '02', '03', '04'].contains(normalized)) {
      return {'code': 'operating', 'type_name': 'งบดำเนินงาน', 'sort': 2};
    }
    if (['05', '06'].contains(normalized)) {
      return {'code': 'investment', 'type_name': 'งบลงทุน', 'sort': 3};
    }
    if (normalized == '07') {
      return {'code': 'subsidy', 'type_name': 'งบเงินอุดหนุน', 'sort': 4};
    }
    return {'code': 'other', 'type_name': 'อื่น ๆ', 'sort': 5};
  }

  static List<Map<String, dynamic>> groupExpenseRowsByOfficialSection(
    List<Map<String, Object?>> rows,
  ) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final meta = expenseReportGroupForCode(row['code']?.toString());
      final key = meta['code']! as String;
      final current = grouped.putIfAbsent(
        key,
        () => {
          'code': key,
          'type_name': meta['type_name'],
          'total': 0.0,
          'count': 0,
          'sort': meta['sort'],
          'lines': <Map<String, Object?>>[],
        },
      );
      current['total'] = (current['total'] as double) + _d(row['total']);
      current['count'] = (current['count'] as int) +
          (int.tryParse(row['count']?.toString() ?? '0') ?? 0);
      (current['lines'] as List<Map<String, Object?>>).add(row);
    }
    final out = grouped.values.toList()
      ..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    return out.map((row) {
      final copy = Map<String, dynamic>.from(row);
      copy.remove('sort');
      return copy;
    }).toList();
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  static void _addBankMovement(
    Map<String, double> target,
    Map<String, Object?> row,
  ) {
    if (PocketClassifier.pocketKey(row['mt_name']?.toString()) !=
        PocketClassifier.pocketBank) {
      return;
    }
    final slotRaw = row['bank_slot']?.toString().trim() ?? '';
    final slot = slotRaw.isEmpty ? '__null__' : slotRaw;
    target[slot] = (target[slot] ?? 0) + _d(row['amount']);
  }

  static double _sumRowsForPocket(
    List<Map<String, Object?>> rows,
    String pocket,
  ) {
    var total = 0.0;
    for (final row in rows) {
      if (PocketClassifier.pocketKey(row['mt_name']?.toString()) != pocket) {
        continue;
      }
      total += _d(row['amount']);
    }
    return total;
  }
}
