import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/platform/local_file_ops.dart';
import 'package:saccm/features/setting/data/school_profile_csv_header.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';

class ReportsCsvExportOutcome {
  const ReportsCsvExportOutcome({
    required this.userMessage,
    required this.displaySeconds,
  });

  final String userMessage;
  final int displaySeconds;
}

class ReportsCsvExportService {
  ReportsCsvExportService({NumberFormat? numberFormat})
      : _fmt = numberFormat ?? NumberFormat('#,##0.00');

  final NumberFormat _fmt;

  String _csvEscape(String value) => '"${value.replaceAll('"', '""')}"';

  String buildBudgetSourceCsv({
    required SchoolProfile schoolProfile,
    required String fiscalYearText,
    required List budgetData,
  }) {
    final rows = <String>[
      ...schoolProfileCsvCommentLines(schoolProfile),
      if (fiscalYearText.isNotEmpty) '# fiscal_year_buddhist: $fiscalYearText',
      TransactionUiText.reportsBudgetCsvHeader,
    ];
    for (final item in budgetData) {
      final budgetYear =
          double.tryParse(item['budget_amount']?.toString() ?? '0') ?? 0;
      final broughtFwd =
          double.tryParse(item['brought_forward_amount']?.toString() ?? '0') ??
              0;
      final budget = budgetYear + broughtFwd;
      final incomeBySource = double.tryParse(
            item['income_amount']?.toString() ??
                item['total_income']?.toString() ??
                item['received_income']?.toString() ??
                '0',
          ) ??
          0;
      final used =
          double.tryParse(item['used_expense']?.toString() ?? '0') ?? 0;
      final remaining = item['remaining'] != null
          ? (double.tryParse(item['remaining']?.toString() ?? '') ??
              (budget - used))
          : (budget - used);
      final netBalance = incomeBySource - used;
      final usedPercent =
          double.tryParse(item['used_percent']?.toString() ?? '0') ?? 0;

      rows.add([
        _csvEscape(item['code']?.toString() ?? ''),
        _csvEscape(item['name']?.toString() ?? ''),
        _csvEscape(_fmt.format(budget)),
        _csvEscape(_fmt.format(incomeBySource)),
        _csvEscape(_fmt.format(used)),
        _csvEscape(_fmt.format(remaining)),
        _csvEscape(_fmt.format(netBalance)),
        _csvEscape(usedPercent.toStringAsFixed(1)),
      ].join(','));
    }

    final totalBudget = budgetData.fold<double>(0, (sum, item) {
      final y = double.tryParse(item['budget_amount']?.toString() ?? '0') ?? 0;
      final bf =
          double.tryParse(item['brought_forward_amount']?.toString() ?? '0') ??
              0;
      return sum + y + bf;
    });
    final totalIncome = budgetData.fold<double>(
      0,
      (sum, item) =>
          sum +
          (double.tryParse(
                item['income_amount']?.toString() ??
                    item['total_income']?.toString() ??
                    item['received_income']?.toString() ??
                    '0',
              ) ??
              0),
    );
    final totalUsed = budgetData.fold<double>(
      0,
      (sum, item) =>
          sum + (double.tryParse(item['used_expense']?.toString() ?? '0') ?? 0),
    );
    final totalRemaining = totalBudget - totalUsed;
    final totalNetBalance = totalIncome - totalUsed;
    final totalUsedPercent =
        totalBudget > 0 ? (totalUsed / totalBudget) * 100 : 0.0;

    rows.add([
      _csvEscape('TOTAL'),
      _csvEscape(TransactionUiText.reportsBudgetSourceTotalLabel),
      _csvEscape(_fmt.format(totalBudget)),
      _csvEscape(_fmt.format(totalIncome)),
      _csvEscape(_fmt.format(totalUsed)),
      _csvEscape(_fmt.format(totalRemaining)),
      _csvEscape(_fmt.format(totalNetBalance)),
      _csvEscape(totalUsedPercent.toStringAsFixed(1)),
    ].join(','));

    return rows.join('\n');
  }

  Future<ReportsCsvExportOutcome> exportBudgetSourceCsv({
    required SchoolProfile schoolProfile,
    required String fiscalYearText,
    required List budgetData,
  }) async {
    final csv = buildBudgetSourceCsv(
      schoolProfile: schoolProfile,
      fiscalYearText: fiscalYearText,
      budgetData: budgetData,
    );
    return _saveCsv(
      'budget_source_report_${DateTime.now().millisecondsSinceEpoch}.csv',
      csv,
    );
  }

  Future<ReportsCsvExportOutcome> _saveCsv(
    String filename,
    String csv,
  ) async {
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: csv));
      return const ReportsCsvExportOutcome(
        userMessage: TransactionUiText.reportsCsvCopied,
        displaySeconds: 2,
      );
    }

    final file = await writeTextFileToDocuments(filename: filename, content: csv);
    if (file == null) {
      await Clipboard.setData(ClipboardData(text: csv));
      return const ReportsCsvExportOutcome(
        userMessage: TransactionUiText.reportsCsvCopied,
        displaySeconds: 2,
      );
    }

    return ReportsCsvExportOutcome(
      userMessage: '${TransactionUiText.reportsCsvSavedAtPrefix} ${file.path}',
      displaySeconds: 3,
    );
  }

  String buildAnnualSummaryCsv({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String fiscalYearText,
  }) {
    final fy = data['fiscal_year']?.toString() ?? fiscalYearText;
    final rows = <String>[
      ...schoolProfileCsvCommentLines(schoolProfile),
      if (fy.isNotEmpty) '# fiscal_year_buddhist: $fy',
      TransactionUiText.reportsAnnualCsvHeader,
    ];

    void appendSection(String section, List? list) {
      if (list == null) return;
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        rows.add([
          _csvEscape(section),
          _csvEscape(m['code']?.toString() ?? ''),
          _csvEscape(m['type_name']?.toString() ?? ''),
          _csvEscape(_fmt.format(
              double.tryParse(m['total']?.toString() ?? '0') ?? 0)),
          _csvEscape('${int.tryParse(m['count']?.toString() ?? '0') ?? 0}'),
        ].join(','));
      }
    }

    appendSection('income', data['income'] as List?);
    appendSection('expense', data['expense'] as List?);
    return rows.join('\n');
  }

  Future<ReportsCsvExportOutcome> exportAnnualSummaryCsv({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String fiscalYearText,
  }) async {
    final csv = buildAnnualSummaryCsv(
      schoolProfile: schoolProfile,
      data: data,
      fiscalYearText: fiscalYearText,
    );
    final fy = data['fiscal_year']?.toString() ?? fiscalYearText;
    return _saveCsv('annual_summary_$fy.csv', csv);
  }

  String buildDailyBalanceCsv({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String reportDate,
  }) {
    final rows = <String>[
      ...schoolProfileCsvCommentLines(schoolProfile),
      '# report_date: $reportDate',
      TransactionUiText.reportsDailyBalanceCsvHeader,
    ];

    void appendRow(Map<String, dynamic> r, {bool sub = false}) {
      double m(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
      final label = r['label']?.toString() ?? '';
      rows.add([
        _csvEscape(sub ? '  $label' : label),
        _csvEscape(_fmt.format(m(r['cash']))),
        _csvEscape(_fmt.format(m(r['bank']))),
        _csvEscape(_fmt.format(m(r['agency']))),
        _csvEscape(_fmt.format(m(r['total']))),
        _csvEscape(r['remark']?.toString() ?? ''),
      ].join(','));
    }

    final rawRows = data['rows'];
    if (rawRows is List) {
      for (final raw in rawRows) {
        final r = Map<String, dynamic>.from(raw as Map);
        appendRow(r);
        final subs = r['sub_rows'];
        if (subs is List) {
          for (final s in subs) {
            appendRow(Map<String, dynamic>.from(s as Map), sub: true);
          }
        }
      }
    }
    return rows.join('\n');
  }

  Future<ReportsCsvExportOutcome> exportDailyBalanceCsv({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String reportDate,
  }) async {
    final csv = buildDailyBalanceCsv(
      schoolProfile: schoolProfile,
      data: data,
      reportDate: reportDate,
    );
    return _saveCsv('daily_balance_$reportDate.csv', csv);
  }
}
