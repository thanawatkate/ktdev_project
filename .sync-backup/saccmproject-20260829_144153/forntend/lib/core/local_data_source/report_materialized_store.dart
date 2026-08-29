import 'package:sqflite/sqflite.dart';
import 'package:saccm/core/local_data_source/reports_local_data_source.dart';

/// Persist `/reports/*` aggregate responses per fiscal year (Buddhist) in SQLite.
/// Child rows reference [report_snapshot] and optionally [budget_source_budget].
class ReportMaterializedStore {
  ReportMaterializedStore._();

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  static int _i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static Future<Set<String>> _budgetIdsThatExist(Transaction txn) async {
    final rows = await txn.query('budget_source_budget', columns: ['id']);
    return rows.map((e) => e['id']!.toString()).toSet();
  }

  static Future<Map<String, dynamic>> _loadAnnualSummary(
    Database db,
    String fiscalYear,
  ) async {
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
      'expense': ReportsLocalDataSource.groupExpenseRowsByOfficialSection(
        expenseDetails,
      ),
      'expense_details': expenseDetails,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'balance': totalIncome - totalExpense,
      'source': 'local_cache',
    };
  }

  /// Replace all materialized rows for [fiscalYear] with [bundle] (same shape as UI bundle).
  static Future<void> replaceBundle(
    Database db,
    String fiscalYear,
    Map<String, dynamic> bundle,
  ) async {
    final fy = fiscalYear.trim();
    if (fy.isEmpty) return;

    await db.transaction((txn) async {
      await txn
          .delete('report_snapshot', where: 'fiscal_year = ?', whereArgs: [fy]);

      final summary = bundle['summary'];
      final s = summary is Map
          ? Map<String, dynamic>.from(summary)
          : <String, dynamic>{};

      final snapId = await txn.insert('report_snapshot', {
        'fiscal_year': fy,
        'total_income': _d(s['total_income']),
        'total_expense': _d(s['total_expense']),
        'total_loan': _d(s['total_loan']),
        'total_repay': _d(s['total_repay']),
        'balance': _d(s['balance']),
        'net_cash_flow': _d(s['net_cash_flow']),
        'fetched_at': DateTime.now().toIso8601String(),
      });

      final budgetIds = await _budgetIdsThatExist(txn);

      var sort = 0;
      for (final raw in bundle['incomeByMonth'] as List? ?? const []) {
        final m =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        await txn.insert('report_income_by_month', {
          'ref_report_snapshot': snapId,
          'month': m['month']?.toString() ?? '',
          'total': _d(m['total']),
          'txn_count': _i(m['count']),
        });
      }
      for (final raw in bundle['expenseByMonth'] as List? ?? const []) {
        final m =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        await txn.insert('report_expense_by_month', {
          'ref_report_snapshot': snapId,
          'month': m['month']?.toString() ?? '',
          'total': _d(m['total']),
          'txn_count': _i(m['count']),
        });
      }
      sort = 0;
      for (final raw in bundle['budgetData'] as List? ?? const []) {
        final m =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final bid = m['id']?.toString();
        final refB = bid != null && budgetIds.contains(bid) ? bid : null;
        await txn.insert('report_budget_source_line', {
          'ref_report_snapshot': snapId,
          'sort_order': sort++,
          'server_budget_id': bid,
          'ref_budget_source_budget': refB,
          'code': m['code']?.toString(),
          'name': m['name']?.toString(),
          'budget_type': m['budget_type']?.toString(),
          'fiscal_year': m['fiscal_year']?.toString(),
          'budget_amount': _d(m['budget_amount']),
          'brought_forward_amount': _d(m['brought_forward_amount']),
          'used_expense': _d(m['used_expense']),
          'received_income': _d(
            m['received_income'] ?? m['income_amount'] ?? m['total_income'],
          ),
          'remaining': _d(m['remaining']),
          'used_percent': m['used_percent']?.toString(),
        });
      }

      final tb = bundle['trialBalance'];
      if (tb is Map) {
        final tbm = Map<String, dynamic>.from(tb);
        for (final raw in tbm['income'] as List? ?? const []) {
          final m =
              raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          await txn.insert('report_trial_balance_line', {
            'ref_report_snapshot': snapId,
            'side': 'income',
            'type_name': m['type_name']?.toString(),
            'total': _d(m['total']),
            'txn_count': _i(m['count']),
          });
        }
        for (final raw in tbm['expense'] as List? ?? const []) {
          final m =
              raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          await txn.insert('report_trial_balance_line', {
            'ref_report_snapshot': snapId,
            'side': 'expense',
            'type_name': m['type_name']?.toString(),
            'total': _d(m['total']),
            'txn_count': _i(m['count']),
          });
        }
      }

      sort = 0;
      for (final raw in bundle['budgetRemaining'] as List? ?? const []) {
        final m =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final bid = m['id']?.toString();
        final refB = bid != null && budgetIds.contains(bid) ? bid : null;
        await txn.insert('report_budget_remaining_line', {
          'ref_report_snapshot': snapId,
          'sort_order': sort++,
          'server_budget_id': bid,
          'ref_budget_source_budget': refB,
          'code': m['code']?.toString(),
          'name': m['name']?.toString(),
          'budget_type': m['budget_type']?.toString(),
          'fiscal_year': m['fiscal_year']?.toString(),
          'budget_amount': _d(m['budget_amount']),
          'brought_forward_amount': _d(m['brought_forward_amount']),
          'used_amount': _d(m['used_amount']),
          'remaining': _d(m['remaining']),
          'used_percent': _d(m['used_percent']),
        });
      }
    });
  }

  /// Returns bundle map for [_applyReportBundle] or null.
  static Future<Map<String, dynamic>?> loadBundle(
    Database db,
    String fiscalYear,
  ) async {
    final fy = fiscalYear.trim();
    if (fy.isEmpty) return null;

    final snaps = await db.query(
      'report_snapshot',
      where: 'fiscal_year = ?',
      whereArgs: [fy],
      limit: 1,
    );
    if (snaps.isEmpty) return null;
    final sid = snaps.first['id'] as int;

    final summary = <String, dynamic>{
      'total_income': _d(snaps.first['total_income']),
      'total_expense': _d(snaps.first['total_expense']),
      'total_loan': _d(snaps.first['total_loan']),
      'total_repay': _d(snaps.first['total_repay']),
      'balance': _d(snaps.first['balance']),
      'net_cash_flow': _d(snaps.first['net_cash_flow']),
    };

    final incomeRows = await db.query(
      'report_income_by_month',
      where: 'ref_report_snapshot = ?',
      whereArgs: [sid],
      orderBy: 'month ASC',
    );
    final incomeByMonth = incomeRows
        .map(
          (r) => {
            'month': r['month'],
            'total': r['total'],
            'count': r['txn_count'],
          },
        )
        .toList();

    final expenseRows = await db.query(
      'report_expense_by_month',
      where: 'ref_report_snapshot = ?',
      whereArgs: [sid],
      orderBy: 'month ASC',
    );
    final expenseByMonth = expenseRows
        .map(
          (r) => {
            'month': r['month'],
            'total': r['total'],
            'count': r['txn_count'],
          },
        )
        .toList();

    final budgetRows = await db.query(
      'report_budget_source_line',
      where: 'ref_report_snapshot = ?',
      whereArgs: [sid],
      orderBy: 'sort_order ASC',
    );
    final budgetData = budgetRows.map((r) {
      final id = r['server_budget_id']?.toString() ??
          r['ref_budget_source_budget']?.toString() ??
          r['code'];
      return <String, dynamic>{
        'id': id,
        'code': r['code'],
        'name': r['name'],
        'budget_type': r['budget_type'],
        'fiscal_year': r['fiscal_year'],
        'budget_amount': r['budget_amount'],
        'brought_forward_amount': r['brought_forward_amount'],
        'used_expense': r['used_expense'],
        'received_income': r['received_income'],
        'income_amount': r['received_income'],
        'remaining': r['remaining'],
        'used_percent': r['used_percent'],
      };
    }).toList();

    final trialRows = await db.query(
      'report_trial_balance_line',
      where: 'ref_report_snapshot = ?',
      whereArgs: [sid],
      orderBy: 'side ASC, id ASC',
    );
    final incomeTrial = <Map<String, dynamic>>[];
    final expenseTrial = <Map<String, dynamic>>[];
    for (final r in trialRows) {
      final row = {
        'type_name': r['type_name'],
        'total': r['total'],
        'count': r['txn_count'],
      };
      if (r['side'] == 'expense') {
        expenseTrial.add(row);
      } else {
        incomeTrial.add(row);
      }
    }
    final trialBalance = {
      'income': incomeTrial,
      'expense': expenseTrial,
    };

    final remRows = await db.query(
      'report_budget_remaining_line',
      where: 'ref_report_snapshot = ?',
      whereArgs: [sid],
      orderBy: 'sort_order ASC',
    );
    final budgetRemaining = remRows
        .map(
          (r) => {
            'id': r['server_budget_id']?.toString() ??
                r['ref_budget_source_budget']?.toString() ??
                r['code'],
            'code': r['code'],
            'name': r['name'],
            'budget_type': r['budget_type'],
            'fiscal_year': r['fiscal_year'],
            'budget_amount': r['budget_amount'],
            'brought_forward_amount': r['brought_forward_amount'],
            'used_amount': r['used_amount'],
            'remaining': r['remaining'],
            'used_percent': r['used_percent'],
          },
        )
        .toList();
    final annualSummary = await _loadAnnualSummary(db, fy);

    return {
      'summary': summary,
      'incomeByMonth': incomeByMonth,
      'expenseByMonth': expenseByMonth,
      'budgetData': budgetData,
      'trialBalance': trialBalance,
      'budgetRemaining': budgetRemaining,
      'annualSummary': annualSummary,
    };
  }
}
