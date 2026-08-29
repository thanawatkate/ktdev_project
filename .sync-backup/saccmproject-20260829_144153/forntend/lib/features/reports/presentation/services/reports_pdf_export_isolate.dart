import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/thai_date_formatter.dart';
import 'package:saccm/features/reports/presentation/services/reports_pdf_fonts.dart';

class AnnualSummaryPdfJob {
  const AnnualSummaryPdfJob({
    required this.regularFont,
    required this.boldFont,
    required this.schoolName,
    required this.data,
    required this.fiscalYearText,
  });

  final Uint8List regularFont;
  final Uint8List boldFont;
  final String schoolName;
  final Map<String, dynamic> data;
  final String fiscalYearText;
}

class DailyBalancePdfJob {
  const DailyBalancePdfJob({
    required this.regularFont,
    required this.boldFont,
    required this.schoolName,
    required this.data,
    required this.reportDate,
  });

  final Uint8List regularFont;
  final Uint8List boldFont;
  final String schoolName;
  final Map<String, dynamic> data;
  final String reportDate;
}

class BankReconciliationPdfJob {
  const BankReconciliationPdfJob({
    required this.regularFont,
    required this.boldFont,
    required this.schoolName,
    required this.data,
    required this.reportDate,
  });

  final Uint8List regularFont;
  final Uint8List boldFont;
  final String schoolName;
  final Map<String, dynamic> data;
  final String reportDate;
}

Future<Uint8List> runPdfInBackground(Future<Uint8List> Function() build) {
  if (kIsWeb) return build();
  return Isolate.run(build);
}

Future<Uint8List> buildAnnualSummaryPdfBytes(AnnualSummaryPdfJob job) async {
  final regular = ReportsPdfFonts.fontsFromBytes(job.regularFont, job.boldFont);
  final bold = ReportsPdfFonts.boldFromBytes(job.boldFont);
  final fmt = NumberFormat('#,##0.00');

  pw.TextStyle style({bool isBold = false, double size = 11}) => pw.TextStyle(
        font: isBold ? bold : regular,
        fontSize: size,
      );

  pw.Widget schoolHeader(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (job.schoolName.isNotEmpty)
          pw.Text(job.schoolName, style: style(isBold: true, size: 14)),
        pw.SizedBox(height: 4),
        pw.Text(title, style: style(isBold: true, size: 13)),
        pw.Text(subtitle, style: style(size: 10)),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget moneyTable({
    required List<String> headers,
    required List<List<String>> rows,
    List<int> numericCols = const [],
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    h,
                    style: style(isBold: true, size: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: List.generate(row.length, (i) {
              final numeric = numericCols.contains(i);
              return pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  row[i],
                  style: style(size: 9),
                  textAlign: numeric ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<List<String>> detailRows(List? list) {
    if (list == null || list.isEmpty) {
      return [
        ['-', TransactionUiText.noData, '0.00', '0'],
      ];
    }
    return list.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return [
        m['code']?.toString() ?? '',
        m['type_name']?.toString() ?? '',
        fmt.format(double.tryParse(m['total']?.toString() ?? '0') ?? 0),
        '${int.tryParse(m['count']?.toString() ?? '0') ?? 0}',
      ];
    }).toList();
  }

  final fy = job.data['fiscal_year']?.toString() ?? job.fiscalYearText;
  final incomeRows = detailRows(job.data['income'] as List?);
  final expenseRows = detailRows(job.data['expense'] as List?);
  final totalIncome =
      double.tryParse(job.data['total_income']?.toString() ?? '0') ?? 0;
  final totalExpense =
      double.tryParse(job.data['total_expense']?.toString() ?? '0') ?? 0;
  final balance = double.tryParse(job.data['balance']?.toString() ?? '0') ?? 0;

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        schoolHeader(
          TransactionUiText.annualSummaryTab,
          '${TransactionUiText.reportsFiscalYearPrefix} $fy',
        ),
        pw.Text(TransactionUiText.reportsAnnualIncomeByType,
            style: style(isBold: true)),
        pw.SizedBox(height: 4),
        moneyTable(
          headers: [
            TransactionUiText.reportsColCode,
            TransactionUiText.reportsColType,
            TransactionUiText.reportsColAmount,
            TransactionUiText.reportsColDocuments,
          ],
          rows: incomeRows,
          numericCols: const [2, 3],
        ),
        pw.SizedBox(height: 12),
        pw.Text(TransactionUiText.reportsAnnualExpenseByRefType,
            style: style(isBold: true)),
        pw.SizedBox(height: 4),
        moneyTable(
          headers: [
            TransactionUiText.reportsColCode,
            TransactionUiText.reportsColType,
            TransactionUiText.reportsColAmount,
            TransactionUiText.reportsColDocuments,
          ],
          rows: expenseRows,
          numericCols: const [2, 3],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  '${TransactionUiText.totalIncomeLabel}: ${fmt.format(totalIncome)}',
                  style: style(),
                ),
                pw.Text(
                  '${TransactionUiText.totalExpenseLabel}: ${fmt.format(totalExpense)}',
                  style: style(),
                ),
                pw.Text(
                  '${TransactionUiText.remaining}: ${fmt.format(balance)}',
                  style: style(isBold: true),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> buildDailyBalancePdfBytes(DailyBalancePdfJob job) async {
  final regular = ReportsPdfFonts.fontsFromBytes(job.regularFont, job.boldFont);
  final bold = ReportsPdfFonts.boldFromBytes(job.boldFont);
  final fmt = NumberFormat('#,##0.00');

  pw.TextStyle style({bool isBold = false, double size = 11}) => pw.TextStyle(
        font: isBold ? bold : regular,
        fontSize: size,
      );

  List<String> dailyBalanceRow(Map<String, dynamic> r, {bool sub = false}) {
    double m(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    final label = r['label']?.toString() ?? '';
    return [
      sub ? '  $label' : label,
      fmt.format(m(r['cash'])),
      fmt.format(m(r['bank'])),
      fmt.format(m(r['agency'])),
      fmt.format(m(r['total'])),
      r['remark']?.toString() ?? '',
    ];
  }

  final rows = <List<String>>[];
  final rawRows = job.data['rows'];
  if (rawRows is List) {
    for (final raw in rawRows) {
      final r = Map<String, dynamic>.from(raw as Map);
      rows.add(dailyBalanceRow(r));
      final subs = r['sub_rows'];
      if (subs is List) {
        for (final s in subs) {
          rows.add(dailyBalanceRow(
            Map<String, dynamic>.from(s as Map),
            sub: true,
          ));
        }
      }
    }
  }

  final cash = double.tryParse(job.data['cash']?.toString() ?? '0') ?? 0;
  final bank = double.tryParse(job.data['bank']?.toString() ?? '0') ?? 0;
  final agency = double.tryParse(job.data['agency']?.toString() ?? '0') ?? 0;
  final total = double.tryParse(job.data['total']?.toString() ?? '0') ?? 0;
  final dateLabel = ThaiDateFormatter.formatFull(
    DateTime.tryParse(job.reportDate) ?? DateTime.now(),
  );

  pw.Widget moneyTable({
    required List<String> headers,
    required List<List<String>> tableRows,
    List<int> numericCols = const [],
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    h,
                    style: style(isBold: true, size: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        ...tableRows.map(
          (row) => pw.TableRow(
            children: List.generate(row.length, (i) {
              final numeric = numericCols.contains(i);
              return pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  row[i],
                  style: style(size: 9),
                  textAlign: numeric ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (job.schoolName.isNotEmpty)
              pw.Text(job.schoolName, style: style(isBold: true, size: 14)),
            pw.SizedBox(height: 4),
            pw.Text(TransactionUiText.dailyBalanceTab,
                style: style(isBold: true, size: 13)),
            pw.Text(
              '${TransactionUiText.reportsDateLabel}: $dateLabel',
              style: style(size: 10),
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        pw.Text(TransactionUiText.reportsDailySevenRowsTitle,
            style: style(isBold: true)),
        pw.SizedBox(height: 4),
        moneyTable(
          headers: [
            TransactionUiText.reportsDailyColCategory,
            TransactionUiText.reportsDailyColCash,
            TransactionUiText.reportsDailyColBank,
            TransactionUiText.reportsDailyColAgency,
            TransactionUiText.reportsDailyColTotal,
            TransactionUiText.reportsDailyColRemark,
          ],
          tableRows: rows,
          numericCols: const [1, 2, 3, 4],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          '${TransactionUiText.reportsCashTotalLabel}: ${fmt.format(cash)}   '
          '${TransactionUiText.reportsBankTotalLabel}: ${fmt.format(bank)}   '
          '${TransactionUiText.reportsAgencyTotalLabel}: ${fmt.format(agency)}   '
          '${TransactionUiText.reportsGrandTotalLabel}: ${fmt.format(total)}',
          style: style(isBold: true, size: 10),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> buildBankReconciliationPdfBytes(
  BankReconciliationPdfJob job,
) async {
  final regular = ReportsPdfFonts.fontsFromBytes(job.regularFont, job.boldFont);
  final bold = ReportsPdfFonts.boldFromBytes(job.boldFont);
  final fmt = NumberFormat('#,##0.00');

  pw.TextStyle style({bool isBold = false, double size = 11}) => pw.TextStyle(
        font: isBold ? bold : regular,
        fontSize: size,
      );

  double m(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
  final dateLabel = ThaiDateFormatter.formatFull(
    DateTime.tryParse(job.reportDate) ?? DateTime.now(),
  );

  final summaryRows = [
    [
      TransactionUiText.reportsBankOpeningLabel,
      fmt.format(m(job.data['total_opening'])),
    ],
    [
      TransactionUiText.reportsBankInLabel,
      fmt.format(m(job.data['total_in_bank'])),
    ],
    [
      TransactionUiText.reportsBankOutLabel,
      fmt.format(m(job.data['total_out_bank'])),
    ],
    [
      TransactionUiText.reportsBankBookBalanceLabel,
      fmt.format(m(job.data['book_balance'])),
    ],
    [
      TransactionUiText.reportsBankOutstandingChequeLabel,
      fmt.format(m(job.data['outstanding_cheque_total'])),
    ],
    [
      TransactionUiText.reportsBankStatementLabel,
      fmt.format(m(job.data['reconciled_statement_balance'])),
    ],
  ];

  final accounts = (job.data['accounts'] as List?) ?? const [];
  final accountRows = accounts.map((a) {
    final row = Map<String, dynamic>.from(a as Map);
    return [
      row['bank_name']?.toString() ?? '',
      row['accountnumber']?.toString() ?? '',
      fmt.format(m(row['opening_balance'])),
      fmt.format(m(row['total_in_bank'])),
      fmt.format(m(row['total_out_bank'])),
      fmt.format(m(row['book_balance'])),
    ];
  }).toList();
  if (accountRows.isEmpty) {
    accountRows.add([
      TransactionUiText.reportsNoBankAccounts,
      '',
      '0.00',
      '0.00',
      '0.00',
      '0.00',
    ]);
  }

  pw.Widget moneyTable({
    required List<String> headers,
    required List<List<String>> tableRows,
    List<int> numericCols = const [],
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    h,
                    style: style(isBold: true, size: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        ...tableRows.map(
          (row) => pw.TableRow(
            children: List.generate(row.length, (i) {
              final numeric = numericCols.contains(i);
              return pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  row[i],
                  style: style(size: 9),
                  textAlign: numeric ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (job.schoolName.isNotEmpty)
              pw.Text(job.schoolName, style: style(isBold: true, size: 14)),
            pw.SizedBox(height: 4),
            pw.Text(TransactionUiText.bankReconciliationTab,
                style: style(isBold: true, size: 13)),
            pw.Text(
              '${TransactionUiText.reportsDateLabel}: $dateLabel',
              style: style(size: 10),
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        pw.Text(TransactionUiText.reportsBankSummaryTitle,
            style: style(isBold: true)),
        pw.SizedBox(height: 4),
        moneyTable(
          headers: [
            TransactionUiText.reportsColType,
            TransactionUiText.reportsColAmount,
          ],
          tableRows: summaryRows,
          numericCols: const [1],
        ),
        pw.SizedBox(height: 12),
        pw.Text(TransactionUiText.reportsBankAccountsTitle,
            style: style(isBold: true)),
        pw.SizedBox(height: 4),
        moneyTable(
          headers: [
            TransactionUiText.bankAccount,
            TransactionUiText.reportsBankAccountNumberCol,
            TransactionUiText.reportsBankOpeningLabel,
            TransactionUiText.reportsBankInLabel,
            TransactionUiText.reportsBankOutLabel,
            TransactionUiText.reportsBankBookBalanceLabel,
          ],
          tableRows: accountRows,
          numericCols: const [2, 3, 4, 5],
        ),
      ],
    ),
  );
  return doc.save();
}
