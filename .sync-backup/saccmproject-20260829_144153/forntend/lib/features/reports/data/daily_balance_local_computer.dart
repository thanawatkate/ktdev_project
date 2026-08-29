import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/core/utils/pocket_classifier.dart';
import 'package:saccm/features/fiscal_year_opening/data/datasources/fiscal_year_opening_local_data_source.dart';
import 'package:sqflite/sqflite.dart';

/// คำนวณรายงานเงินคงเหลือประจำวัน (คู่มือหน้า 34) จาก SQLite
/// สอดคล้อง `extra_reports.service.js` `getDailyBalance` ในระดับ bucket × pocket
class DailyBalanceLocalComputer {
  DailyBalanceLocalComputer({FiscalYearOpeningLocalDataSource? openingDs})
      : _openingDs = openingDs ?? FiscalYearOpeningLocalDataSource();

  final FiscalYearOpeningLocalDataSource _openingDs;

  static const _mgState = '1';
  static const _mgOff = '2';
  static const _mgTax = '3';
  static const _mgGuarantee = '4';
  static const _mgBudget = '5';

  Future<Map<String, dynamic>> compute(Database db, String isoDate) async {
    final day = isoDate.trim().length >= 10
        ? isoDate.trim().substring(0, 10)
        : isoDate.trim();
    final dateEnd = '$day 23:59:59';
    final fy = FiscalYear.currentBuddhist(
      now: DateTime.tryParse(day) ?? DateTime.now(),
    ).toString();

    final openingMap = await _openingDs.loadMapForFiscalYear(fy);

    final budgetP = await _netPockets(
      db,
      dateEnd,
      incomeWhere: _mgBudgetSql('i', 'bsm'),
      expenseWhere: _mgBudgetSql('e', 'bsm'),
    );
    final stateP = await _netPockets(
      db,
      dateEnd,
      incomeWhere: "bsm.refmoneygroup = '$_mgState'",
      expenseWhere: "bsm.refmoneygroup = '$_mgState'",
    );
    final ob12P = await _netPockets(
      db,
      dateEnd,
      incomeWhere: "bsm.refmoneygroup = '$_mgOff' AND it.code = 'OB-12'",
      expenseWhere: "bsm.refmoneygroup = '$_mgOff' AND it.code = 'OB-12'",
    );
    final offP = await _netPockets(
      db,
      dateEnd,
      incomeWhere: _offbudgetIncomeSql(),
      expenseWhere: _offbudgetExpenseSql(),
    );
    final genP = await _netPockets(
      db,
      dateEnd,
      incomeWhere: "it.code IN ('OB-01','OB-02')",
      expenseWhere: "it.code IN ('OB-01','OB-02')",
    );
    final genPerHeadP = await _netPockets(
      db,
      dateEnd,
      incomeWhere: "it.code = 'OB-01'",
      expenseWhere: "it.code = 'OB-01'",
    );
    final genPoorP = await _netPockets(
      db,
      dateEnd,
      incomeWhere: "it.code = 'OB-02'",
      expenseWhere: "it.code = 'OB-02'",
    );
    final schoolP = await _netPockets(
      db,
      dateEnd,
      incomeWhere:
          "bsm.budget_type = 'รายได้สถานศึกษา' OR bsm.refmoneygroup = '$_mgOff' AND bsm.budget_type = 'รายได้สถานศึกษา'",
      expenseWhere:
          "bsm.budget_type = 'รายได้สถานศึกษา' OR bsm.budget_type = 'รายได้สถานศึกษา'",
    );
    final schoolDonationP = await _netPockets(
      db,
      dateEnd,
      incomeWhere:
          "(bsm.budget_type = 'รายได้สถานศึกษา') AND (it.code = '06' OR it.name LIKE '%บริจาค%')",
      expenseWhere:
          "(bsm.budget_type = 'รายได้สถานศึกษา') AND (it.code = '06' OR it.name LIKE '%บริจาค%')",
    );
    final schoolOtherP = await _netPockets(
      db,
      dateEnd,
      incomeWhere:
          "(bsm.budget_type = 'รายได้สถานศึกษา') AND (it.code IS NULL OR it.code <> '06') AND (it.name IS NULL OR it.name NOT LIKE '%บริจาค%')",
      expenseWhere:
          "(bsm.budget_type = 'รายได้สถานศึกษา') AND (it.code IS NULL OR it.code <> '06') AND (it.name IS NULL OR it.name NOT LIKE '%บริจาค%')",
    );
    final taxP = await _netPockets(
      db,
      dateEnd,
      incomeWhere: "bsm.refmoneygroup = '$_mgTax' OR it.code = 'WHT-01'",
      expenseWhere: "bsm.refmoneygroup = '$_mgTax' OR it.code = 'WHT-01'",
    );
    final guarP = await _netPockets(
      db,
      dateEnd,
      incomeWhere: "bsm.refmoneygroup = '$_mgGuarantee' OR it.code = 'GUAR-01'",
      expenseWhere:
          "bsm.refmoneygroup = '$_mgGuarantee' OR it.code = 'GUAR-01'",
    );

    final budgetWithOpen = _addOpening(budgetP, openingMap['budget']);
    final stateNet = _subtractPockets(stateP, ob12P);
    final stateWithOpen = _addOpening(stateNet, openingMap['state_revenue']);
    final offWithOpen = _addOpening(offP, openingMap['offbudget']);
    final genWithOpen = _addOpening(genP, openingMap['general_subsidy']);
    final schoolWithOpen = _addOpening(schoolP, openingMap['school_revenue']);
    final taxWithOpen = _addOpening(taxP, openingMap['withholding_tax']);
    final guarWithOpen = _addOpening(guarP, openingMap['contract_deposit']);

    final ob12Row = _pocketsToRow(
      'ob12',
      'ดอกเบี้ยบัญชีเงินอุดหนุนอื่น (OB-12)',
      'ยอด OB-12 ที่แสดงหักจากแถวแผ่นดินในตารางคู่มือหน้า 34',
      ob12P,
    );

    final rows = [
      _pocketsToRow('budget', 'เงินงบประมาณ', '', budgetWithOpen),
      _pocketsToRow(
        'state_revenue',
        'เงินรายได้แผ่นดิน',
        'สุทธิ = เงินรายได้แผ่นดิน − OB-12',
        stateWithOpen,
        subRows: [ob12Row],
      ),
      _pocketsToRow('offbudget', 'เงินนอกงบประมาณ', '', offWithOpen),
      _pocketsToRow(
        'general_subsidy',
        'เงินอุดหนุนทั่วไป',
        'หมวด OB-01 / OB-02',
        genWithOpen,
        subRows: [
          _pocketsToRow(
            'general_subsidy_per_head',
            'ค่าจัดการเรียนการสอน (OB-01)',
            '',
            genPerHeadP,
          ),
          _pocketsToRow(
            'general_subsidy_poor',
            'ปัจจัยพื้นฐานนักเรียนยากจน (OB-02)',
            '',
            genPoorP,
          ),
        ],
      ),
      _pocketsToRow(
        'school_revenue',
        'เงินรายได้สถานศึกษา',
        'แยกตาม budget_type รายได้สถานศึกษา',
        schoolWithOpen,
        subRows: [
          _pocketsToRow(
              'school_revenue_donation', 'เงินบริจาค', '', schoolDonationP),
          _pocketsToRow(
              'school_revenue_other', 'รายได้สถานศึกษาอื่น', '', schoolOtherP),
        ],
      ),
      _pocketsToRow(
        'withholding_tax',
        'เงินภาษีหัก ณ ที่จ่าย',
        '',
        taxWithOpen,
      ),
      _pocketsToRow('contract_deposit', 'เงินประกันสัญญา', '', guarWithOpen),
    ];

    final grand = _sumRows(rows);
    final keepingLimits = await db.query(
      'cash_keeping_limit',
      where: 'fiscal_year = ? AND is_active = 1',
      whereArgs: [fy],
    );
    final generalSmallLimit =
        keepingLimits.cast<Map<String, Object?>>().firstWhere(
              (row) =>
                  row['fund_kind']?.toString() == 'general' &&
                  row['school_size']?.toString() == 'small',
              orElse: () => const <String, Object?>{},
            );
    final cashLimit = double.tryParse(
      generalSmallLimit['cash_max']?.toString() ?? '',
    );

    return {
      'date': day,
      'fiscal_year': fy,
      'rows': rows,
      'cash': grand[PocketClassifier.pocketCash] ?? 0,
      'bank': grand[PocketClassifier.pocketBank] ?? 0,
      'agency': grand[PocketClassifier.pocketAgency] ?? 0,
      'total': grand.values.fold<double>(0, (sum, value) => sum + value),
      'keeping_limits': keepingLimits,
      'cash_over_limit': cashLimit != null &&
          (grand[PocketClassifier.pocketCash] ?? 0) > cashLimit,
      'cash_limit_used': cashLimit,
      'source': 'local',
    };
  }

  String _mgBudgetSql(String headAlias, String bsmAlias) =>
      "($bsmAlias.refmoneygroup = '$_mgBudget' OR ($bsmAlias.budget_type = 'งปม'))";

  String _offbudgetIncomeSql() => '''
    (bsm.refmoneygroup = '$_mgOff' AND (it.code IS NULL OR it.code NOT IN ('OB-01','OB-02','OB-12'))
     OR (bsm.budget_type = 'นอกงปม' AND (it.code IS NULL OR it.code NOT IN ('OB-01','OB-02','OB-12'))))
  ''';

  String _offbudgetExpenseSql() => _offbudgetIncomeSql();

  Future<Map<String, double>> _netPockets(
    Database db,
    String dateEnd, {
    required String incomeWhere,
    required String expenseWhere,
  }) async {
    final inRows = await _sumIncome(db, dateEnd, incomeWhere);
    final outRows = await _sumExpense(db, dateEnd, expenseWhere);
    return _mergeInOut(inRows, outRows);
  }

  Future<List<Map<String, Object?>>> _sumIncome(
    Database db,
    String dateEnd,
    String extraWhere,
  ) async {
    return db.rawQuery('''
      SELECT mt.name AS mt_name, COALESCE(SUM(CAST(isub.amount AS REAL)), 0) AS total
      FROM income i
      INNER JOIN income_sub isub ON i.id = isub.refIncome
      LEFT JOIN money_type mt ON isub.refMoneyType = mt.id
      LEFT JOIN budget_source_budget bsb ON i.refBudgetSource = bsb.id
      LEFT JOIN budget_source_master bsm ON bsb.refBudgetSourceMaster = bsm.id
      LEFT JOIN income_type it ON isub.refIncomeType = it.id
      WHERE substr(i.docdate, 1, 10) <= substr(?, 1, 10)
        AND ($extraWhere)
      GROUP BY mt.name
    ''', [dateEnd]);
  }

  Future<List<Map<String, Object?>>> _sumExpense(
    Database db,
    String dateEnd,
    String extraWhere,
  ) async {
    return db.rawQuery('''
      SELECT mt.name AS mt_name, COALESCE(SUM(CAST(es.amount AS REAL)), 0) AS total
      FROM expense e
      INNER JOIN expense_sub es ON e.id = es.refExpense
      LEFT JOIN money_type mt ON es.refMoneyType = mt.id
      LEFT JOIN budget_source_budget bsb ON e.refBudgetSource = bsb.id
      LEFT JOIN budget_source_master bsm ON bsb.refBudgetSourceMaster = bsm.id
      LEFT JOIN income_type it ON es.refFundCategory = it.id
      WHERE substr(COALESCE(e.docdate, e.created), 1, 10) <= substr(?, 1, 10)
        AND ($extraWhere)
      GROUP BY mt.name
    ''', [dateEnd]);
  }

  Map<String, double> _mergeInOut(
    List<Map<String, Object?>> inRows,
    List<Map<String, Object?>> outRows,
  ) {
    final pockets = _emptyPockets();
    for (final r in inRows) {
      final key = PocketClassifier.pocketKey(r['mt_name']?.toString());
      pockets[key] = (pockets[key] ?? 0) +
          (double.tryParse(r['total']?.toString() ?? '0') ?? 0);
    }
    for (final r in outRows) {
      final key = PocketClassifier.pocketKey(r['mt_name']?.toString());
      pockets[key] = (pockets[key] ?? 0) -
          (double.tryParse(r['total']?.toString() ?? '0') ?? 0);
    }
    return pockets;
  }

  Map<String, double> _emptyPockets() => {
        PocketClassifier.pocketCash: 0,
        PocketClassifier.pocketBank: 0,
        PocketClassifier.pocketAgency: 0,
      };

  Map<String, double> _subtractPockets(
    Map<String, double> a,
    Map<String, double> b,
  ) {
    final out = _emptyPockets();
    for (final k in out.keys) {
      out[k] = (a[k] ?? 0) - (b[k] ?? 0);
    }
    return out;
  }

  Map<String, double> _addOpening(
    Map<String, double> pockets,
    Map<String, double>? opening,
  ) {
    if (opening == null || opening.isEmpty) return pockets;
    return {
      PocketClassifier.pocketCash:
          (pockets[PocketClassifier.pocketCash] ?? 0) + (opening['cash'] ?? 0),
      PocketClassifier.pocketBank:
          (pockets[PocketClassifier.pocketBank] ?? 0) + (opening['bank'] ?? 0),
      PocketClassifier.pocketAgency:
          (pockets[PocketClassifier.pocketAgency] ?? 0) +
              (opening['agency'] ?? 0),
    };
  }

  Map<String, double> _sumRows(List<Map<String, dynamic>> rows) {
    final out = _emptyPockets();
    for (final row in rows) {
      out[PocketClassifier.pocketCash] =
          (out[PocketClassifier.pocketCash] ?? 0) +
              (double.tryParse(row['cash']?.toString() ?? '0') ?? 0);
      out[PocketClassifier.pocketBank] =
          (out[PocketClassifier.pocketBank] ?? 0) +
              (double.tryParse(row['bank']?.toString() ?? '0') ?? 0);
      out[PocketClassifier.pocketAgency] =
          (out[PocketClassifier.pocketAgency] ?? 0) +
              (double.tryParse(row['agency']?.toString() ?? '0') ?? 0);
    }
    return out;
  }

  Map<String, dynamic> _pocketsToRow(
    String key,
    String label,
    String remark,
    Map<String, double> pockets, {
    List<Map<String, dynamic>>? subRows,
  }) {
    final cash = pockets[PocketClassifier.pocketCash] ?? 0;
    final bank = pockets[PocketClassifier.pocketBank] ?? 0;
    final agency = pockets[PocketClassifier.pocketAgency] ?? 0;
    return {
      'key': key,
      'label': label,
      'remark': remark,
      'cash': cash,
      'bank': bank,
      'agency': agency,
      'total': cash + bank + agency,
      if (subRows != null && subRows.isNotEmpty) 'sub_rows': subRows,
    };
  }
}
