import 'package:saccm/core/local_data_source/app_database.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:sqflite/sqflite.dart';

class StartupReadinessSnapshot {
  const StartupReadinessSnapshot({
    required this.fiscalYear,
    required this.hasSchoolProfile,
    required this.schoolName,
    required this.schoolAddress,
    required this.activeUserCount,
    required this.passwordChangeRequiredCount,
    required this.budgetSourceCount,
    required this.budgetSourceTotalAmount,
    required this.incomeTypeCount,
    required this.offBudgetIncomeTypeCount,
    required this.linkedIncomeTypeCount,
    required this.expenseTypeCount,
    required this.moneyTypeCount,
    required this.partyCount,
    required this.memberCount,
    required this.bankAccountCount,
    required this.chequeAccountCount,
    required this.availableReceiptBookCount,
    required this.docGroupCount,
    required this.cashKeepingLimitCount,
    required this.fiscalYearOpeningCount,
    required this.fiscalYearOpeningTotal,
    required this.appointmentOrderCount,
  });

  final String fiscalYear;
  final bool hasSchoolProfile;
  final String schoolName;
  final String schoolAddress;
  final int activeUserCount;
  final int passwordChangeRequiredCount;
  final int budgetSourceCount;
  final double budgetSourceTotalAmount;
  final int incomeTypeCount;
  final int offBudgetIncomeTypeCount;
  final int linkedIncomeTypeCount;
  final int expenseTypeCount;
  final int moneyTypeCount;
  final int partyCount;
  final int memberCount;
  final int bankAccountCount;
  final int chequeAccountCount;
  final int availableReceiptBookCount;
  final int docGroupCount;
  final int cashKeepingLimitCount;
  final int fiscalYearOpeningCount;
  final double fiscalYearOpeningTotal;
  final int appointmentOrderCount;
}

class StartupReadinessLocalDataSource {
  StartupReadinessLocalDataSource({
    AppDatabase? database,
    SchoolProfileLocalDataSource? schoolProfileLocalDataSource,
  })  : _database = database ?? AppDatabase(),
        _schoolProfileLocalDataSource =
            schoolProfileLocalDataSource ?? SchoolProfileLocalDataSourceImpl();

  final AppDatabase _database;
  final SchoolProfileLocalDataSource _schoolProfileLocalDataSource;

  Future<StartupReadinessSnapshot> load() async {
    final db = await _database.database;
    final school = await _schoolProfileLocalDataSource.load();
    final fiscalYear = FiscalYear.currentBuddhist().toString();
    final budgetSourceTotal = await _sumBudgetSourceAmounts(db, fiscalYear);
    final openingTotal = await _sumFiscalYearOpening(db, fiscalYear);

    return StartupReadinessSnapshot(
      fiscalYear: fiscalYear,
      hasSchoolProfile:
          school.name.trim().isNotEmpty && school.address.trim().isNotEmpty,
      schoolName: school.name.trim(),
      schoolAddress: school.address.trim(),
      activeUserCount: await _count(
        db,
        'users',
        where: 'isActive = 1',
      ),
      passwordChangeRequiredCount: await _count(
        db,
        'users',
        where: 'isActive = 1 AND forcePasswordChange = 1',
      ),
      budgetSourceCount: await _count(
        db,
        'budget_source_budget',
        where: 'fiscal_year = ?',
        whereArgs: [fiscalYear],
      ),
      budgetSourceTotalAmount: budgetSourceTotal,
      incomeTypeCount: await _count(db, 'income_type'),
      offBudgetIncomeTypeCount: await _count(
        db,
        'income_type',
        where: 'code LIKE ?',
        whereArgs: ['OB-%'],
      ),
      linkedIncomeTypeCount: await _countDistinct(
        db,
        'income_type_budget_source_map',
        'refIncomeType',
      ),
      expenseTypeCount: await _count(
        db,
        'expense_type',
        where: "use IS NULL OR use != 'N'",
      ),
      moneyTypeCount: await _count(db, 'money_type'),
      partyCount: await _count(
        db,
        'party',
        where: 'isactive = 1',
      ),
      memberCount: await _count(db, 'member'),
      bankAccountCount: await _count(
        db,
        'bank_account',
        where: "use IS NULL OR use != 'N'",
      ),
      chequeAccountCount: await _count(
        db,
        'cheque_account',
        where: "use IS NULL OR use != 'N'",
      ),
      availableReceiptBookCount: await _count(
        db,
        'receipt_book',
        where: 'status = ?',
        whereArgs: ['available'],
      ),
      docGroupCount: await _count(
        db,
        'doc_group',
        where: "use IS NULL OR use != 'N'",
      ),
      cashKeepingLimitCount: await _count(
        db,
        'cash_keeping_limit',
        where: 'fiscal_year = ? AND is_active = 1',
        whereArgs: [fiscalYear],
      ),
      fiscalYearOpeningCount: await _count(
        db,
        'fiscal_year_opening',
        where: 'fiscal_year = ? AND use = ?',
        whereArgs: [fiscalYear, 'Y'],
      ),
      fiscalYearOpeningTotal: openingTotal,
      appointmentOrderCount: await _count(
        db,
        'appointment_order',
        where: 'status = ?',
        whereArgs: ['active'],
      ),
    );
  }

  Future<int> _count(
    Database db,
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = await db.query(
      table,
      columns: const ['COUNT(*) AS c'],
      where: where,
      whereArgs: whereArgs,
    );
    final raw = rows.isEmpty ? null : rows.first['c'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Future<int> _countDistinct(
    Database db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT $column) AS c FROM $table',
    );
    final raw = rows.isEmpty ? null : rows.first['c'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Future<double> _sumBudgetSourceAmounts(Database db, String fiscalYear) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(budget_amount + brought_forward_amount), 0) AS total
      FROM budget_source_budget
      WHERE fiscal_year = ?
      ''',
      [fiscalYear],
    );
    final raw = rows.isEmpty ? null : rows.first['total'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Future<double> _sumFiscalYearOpening(Database db, String fiscalYear) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(opening_amount), 0) AS total
      FROM fiscal_year_opening
      WHERE fiscal_year = ? AND use = ?
      ''',
      [fiscalYear, 'Y'],
    );
    final raw = rows.isEmpty ? null : rows.first['total'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
