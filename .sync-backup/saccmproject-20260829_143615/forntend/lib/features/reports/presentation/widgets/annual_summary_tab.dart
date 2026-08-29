import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_scroll_table.dart';

class AnnualSummaryTab extends StatelessWidget {
  const AnnualSummaryTab({
    super.key,
    required this.data,
    required this.fiscalYearText,
  });

  final Map<String, dynamic>? data;
  final String fiscalYearText;

  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  static const _columns = [
    ReportsTableColumn(label: TransactionUiText.reportsColCode, size: ColumnSize.S),
    ReportsTableColumn(label: TransactionUiText.reportsColType, size: ColumnSize.L),
    ReportsTableColumn(
      label: TransactionUiText.reportsColAmount,
      numeric: true,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsColDocuments,
      numeric: true,
      size: ColumnSize.S,
    ),
  ];

  List<List<ReportsTableCell>> _rowsFor(List<dynamic>? list) {
    if (list == null || list.isEmpty) return const [];
    return list.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final total = double.tryParse(m['total']?.toString() ?? '0') ?? 0;
      final count = int.tryParse(m['count']?.toString() ?? '0') ?? 0;
      return [
        ReportsTableCell(m['code']?.toString() ?? ''),
        ReportsTableCell(m['type_name']?.toString() ?? '', maxLines: 3),
        ReportsTableCell(_fmt.format(total), numeric: true),
        ReportsTableCell('$count', numeric: true),
      ];
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (data == null) {
      if (fiscalYearText.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              TransactionUiText.reportsAnnualSummaryHintFillFiscalYear,
              style: TextStyle(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              TransactionUiText.reportsAnnualSummaryLoading,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final d = data!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          '${TransactionUiText.reportsFiscalYearPrefix} ${d['fiscal_year'] ?? fiscalYearText}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: c.textPrimary,
            fontFamily: 'Kanit',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          TransactionUiText.reportsAnnualIncomeByType,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: c.incomeGreen,
            fontFamily: 'Kanit',
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ReportsScrollTable(
            columns: _columns,
            rows: _rowsFor(d['income'] as List?),
            headingColor: c.incomeGreen.withValues(alpha: 0.18),
            minWidth: 680,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          TransactionUiText.reportsAnnualExpenseByRefType,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: c.expenseRed,
            fontFamily: 'Kanit',
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ReportsScrollTable(
            columns: _columns,
            rows: _rowsFor(d['expense'] as List?),
            headingColor: c.expenseRed.withValues(alpha: 0.18),
            minWidth: 680,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(
                  c,
                  TransactionUiText.totalIncomeLabel,
                  double.tryParse(d['total_income']?.toString() ?? '0') ?? 0,
                  c.incomeGreen,
                ),
                _kv(
                  c,
                  TransactionUiText.totalExpenseLabel,
                  double.tryParse(d['total_expense']?.toString() ?? '0') ?? 0,
                  c.expenseRed,
                ),
                const Divider(),
                _kv(
                  c,
                  TransactionUiText.remaining,
                  double.tryParse(d['balance']?.toString() ?? '0') ?? 0,
                  c.navy,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(AppColors c, String k, double v, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(k, style: TextStyle(color: c.textSecondary, fontFamily: 'Kanit')),
            const Spacer(),
            Text(
              _fmt.format(v),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontFamily: 'Kanit',
              ),
            ),
          ],
        ),
      );
}
