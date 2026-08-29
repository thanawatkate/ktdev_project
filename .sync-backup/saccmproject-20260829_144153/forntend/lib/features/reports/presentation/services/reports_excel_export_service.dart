import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/platform/local_file_ops.dart';
import 'package:saccm/core/utils/file_download.dart';
import 'package:saccm/features/reports/presentation/services/reports_file_export_outcome.dart';
import 'package:saccm/features/setting/data/school_profile_csv_header.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';

class ReportsExcelExportService {
  ReportsExcelExportService({NumberFormat? numberFormat})
      : _fmt = numberFormat ?? NumberFormat('#,##0.00');

  final NumberFormat _fmt;

  void _writeSchoolHeader(Sheet sheet, SchoolProfile school, int startRow) {
    var row = startRow;
    void comment(String text) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(text);
      row++;
    }

    for (final line in schoolProfileCsvCommentLines(school)) {
      comment(line);
    }
  }

  Future<ReportsFileExportOutcome> exportBudgetSourceExcel({
    required SchoolProfile schoolProfile,
    required String fiscalYearText,
    required List budgetData,
  }) async {
    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet();
    if (defaultName != null) {
      excel.delete(defaultName);
    }
    final sheet = excel['budget_source'];

    var row = 0;
    _writeSchoolHeader(sheet, schoolProfile, row);
    row += schoolProfileCsvCommentLines(schoolProfile).length;
    if (fiscalYearText.isNotEmpty) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('# fiscal_year_buddhist: $fiscalYearText');
      row++;
    }

    final headers = TransactionUiText.reportsBudgetCsvHeader.split(',');
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .value = TextCellValue(headers[c]);
    }
    row++;

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

      final values = [
        item['code']?.toString() ?? '',
        item['name']?.toString() ?? '',
        _fmt.format(budget),
        _fmt.format(incomeBySource),
        _fmt.format(used),
        _fmt.format(remaining),
        _fmt.format(netBalance),
        usedPercent.toStringAsFixed(1),
      ];
      for (var c = 0; c < values.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
            .value = TextCellValue(values[c]);
      }
      row++;
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

    final totalValues = [
      'TOTAL',
      TransactionUiText.reportsBudgetSourceTotalLabel,
      _fmt.format(totalBudget),
      _fmt.format(totalIncome),
      _fmt.format(totalUsed),
      _fmt.format(totalRemaining),
      _fmt.format(totalNetBalance),
      totalUsedPercent.toStringAsFixed(1),
    ];
    for (var c = 0; c < totalValues.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .value = TextCellValue(totalValues[c]);
    }

    return _saveExcel(
      'budget_source_report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      excel,
    );
  }

  Future<ReportsFileExportOutcome> exportAnnualSummaryExcel({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String fiscalYearText,
  }) async {
    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet();
    if (defaultName != null) {
      excel.delete(defaultName);
    }
    final sheet = excel['annual_summary'];
    final fy = data['fiscal_year']?.toString() ?? fiscalYearText;

    var row = 0;
    _writeSchoolHeader(sheet, schoolProfile, row);
    row += schoolProfileCsvCommentLines(schoolProfile).length;
    if (fy.isNotEmpty) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue('# fiscal_year_buddhist: $fy');
      row++;
    }

    final headers = TransactionUiText.reportsAnnualCsvHeader.split(',');
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .value = TextCellValue(headers[c]);
    }
    row++;

    void appendSection(String section, List? list) {
      if (list == null) return;
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final values = [
          section,
          m['code']?.toString() ?? '',
          m['type_name']?.toString() ?? '',
          _fmt.format(double.tryParse(m['total']?.toString() ?? '0') ?? 0),
          '${int.tryParse(m['count']?.toString() ?? '0') ?? 0}',
        ];
        for (var c = 0; c < values.length; c++) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
              .value = TextCellValue(values[c]);
        }
        row++;
      }
    }

    appendSection('income', data['income'] as List?);
    appendSection('expense', data['expense'] as List?);

    return _saveExcel('annual_summary_$fy.xlsx', excel);
  }

  Future<ReportsFileExportOutcome> exportDailyBalanceExcel({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String reportDate,
  }) async {
    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet();
    if (defaultName != null) {
      excel.delete(defaultName);
    }
    final sheet = excel['daily_balance'];

    var row = 0;
    _writeSchoolHeader(sheet, schoolProfile, row);
    row += schoolProfileCsvCommentLines(schoolProfile).length;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('# report_date: $reportDate');
    row++;

    final headers = TransactionUiText.reportsDailyBalanceCsvHeader.split(',');
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .value = TextCellValue(headers[c]);
    }
    row++;

    void appendRow(Map<String, dynamic> r, {bool sub = false}) {
      double m(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
      final label = r['label']?.toString() ?? '';
      final values = [
        sub ? '  $label' : label,
        _fmt.format(m(r['cash'])),
        _fmt.format(m(r['bank'])),
        _fmt.format(m(r['agency'])),
        _fmt.format(m(r['total'])),
        r['remark']?.toString() ?? '',
      ];
      for (var c = 0; c < values.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
            .value = TextCellValue(values[c]);
      }
      row++;
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

    return _saveExcel('daily_balance_$reportDate.xlsx', excel);
  }

  Future<ReportsFileExportOutcome> _saveExcel(
    String filename,
    Excel excel,
  ) async {
    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError(TransactionUiText.reportsExcelEncodeFailed);
    }
    final bytes = Uint8List.fromList(encoded);

    if (kIsWeb) {
      await downloadFileBytes(
        filename: filename,
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      return const ReportsFileExportOutcome(
        userMessage: TransactionUiText.reportsExcelDownloaded,
        displaySeconds: 2,
      );
    }

    final file = await writeBytesFileToDocuments(filename: filename, bytes: bytes);
    if (file == null) {
      await downloadFileBytes(
        filename: filename,
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      return const ReportsFileExportOutcome(
        userMessage: TransactionUiText.reportsExcelDownloaded,
        displaySeconds: 2,
      );
    }

    return ReportsFileExportOutcome(
      userMessage: '${TransactionUiText.reportsExcelSavedAtPrefix} ${file.path}',
      displaySeconds: 3,
    );
  }
}
