import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/platform/local_file_ops.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:saccm/widgets/widgets.dart';

/// ฐานสำหรับแท็บทะเบียนคุมที่เป็น read-only list (ที่ดึงจาก API)
class SimpleRegisterTabBase extends StatefulWidget {
  const SimpleRegisterTabBase({
    super.key,
    required this.loading,
    required this.error,
    required this.rows,
    required this.columnHeaders,
    required this.cellBuilder,
    required this.onRefresh,
    required this.fiscalYear,
    required this.onChangeFiscalYear,
    this.headerInfo,
    this.onRowTap,
    this.csvRowBuilder,
    this.csvFilePrefix = 'register',
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> rows;
  final List<String> columnHeaders;
  final List<DataCell> Function(Map<String, dynamic> row) cellBuilder;
  final VoidCallback onRefresh;
  final int fiscalYear;
  final ValueChanged<int> onChangeFiscalYear;
  final String? headerInfo;
  final void Function(Map<String, dynamic> row)? onRowTap;
  final List<String> Function(Map<String, dynamic> row)? csvRowBuilder;
  final String csvFilePrefix;

  static String formatThaiDate(String? raw) {
    return ThaiDateFormatter.format(raw);
  }

  static String formatNumber(dynamic raw) {
    final v = double.tryParse(raw?.toString() ?? '0') ?? 0;
    return NumberFormat('#,##0.00').format(v);
  }

  @override
  State<SimpleRegisterTabBase> createState() => _SimpleRegisterTabBaseState();
}

class _SimpleRegisterTabBaseState extends State<SimpleRegisterTabBase> {
  late final TextEditingController _fiscalYearCtrl;
  bool _exportingCsv = false;

  @override
  void initState() {
    super.initState();
    _fiscalYearCtrl = TextEditingController(text: widget.fiscalYear.toString());
  }

  @override
  void didUpdateWidget(covariant SimpleRegisterTabBase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fiscalYear != widget.fiscalYear) {
      _fiscalYearCtrl.text = widget.fiscalYear.toString();
    }
  }

  @override
  void dispose() {
    _fiscalYearCtrl.dispose();
    super.dispose();
  }

  void _applyFiscalYearAndRefresh() {
    final parsed =
        int.tryParse(_fiscalYearCtrl.text.trim()) ?? widget.fiscalYear;
    widget.onChangeFiscalYear(parsed);
    widget.onRefresh();
  }

  String _csvEscape(String value) => '"${value.replaceAll('"', '""')}"';

  Future<void> _exportCsv() async {
    final rowBuilder = widget.csvRowBuilder;
    if (_exportingCsv || rowBuilder == null || widget.rows.isEmpty) return;
    setState(() => _exportingCsv = true);
    try {
      final lines = <String>[
        widget.columnHeaders.map(_csvEscape).join(','),
        ...widget.rows.map((r) => rowBuilder(r).map(_csvEscape).join(',')),
      ];
      final csv = lines.join('\n');
      await Clipboard.setData(ClipboardData(text: csv));

      var message = TransactionUiText.reportsCsvCopied;
      if (supportsDesktopFileExport) {
        final safePrefix = widget.csvFilePrefix.replaceAll(
          RegExp(r'[^A-Za-z0-9_-]+'),
          '_',
        );
        final file = await writeTextFileToDocuments(
          filename:
              '${safePrefix}_${widget.fiscalYear}_${DateTime.now().millisecondsSinceEpoch}.csv',
          content: csv,
        );
        if (file != null) {
          message = '${TransactionUiText.reportsCsvSavedAtPrefix} ${file.path}';
        }
      }
      if (!mounted) return;
      showAutoDismissAlert(
        context,
        TransactionUiText.success,
        message,
        3,
      );
    } catch (e) {
      if (!mounted) return;
      showAutoDismissAlert(
        context,
        TransactionUiText.error,
        e.toString(),
        4,
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        color: c.cardWhite,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (widget.headerInfo != null) ...[
            Expanded(
              child: Text(
                widget.headerInfo!,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 200,
            child: BuddhistYearField.picker(
              controller: _fiscalYearCtrl,
              required: false,
              maxYear: BuddhistYearField.toBuddhist(DateTime.now().year + 10),
              onChanged: (_) => _applyFiscalYearAndRefresh(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
              ),
              onPressed: _applyFiscalYearAndRefresh,
              child: const Text(TransactionUiText.view),
            ),
          ),
          if (widget.csvRowBuilder != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                ),
                onPressed:
                    widget.rows.isEmpty || _exportingCsv ? null : _exportCsv,
                icon: _exportingCsv
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: const Text('CSV'),
              ),
            ),
          ],
        ]),
      ),
      if (widget.error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 100,
            child: SingleChildScrollView(
              child: Text(
                widget.error!,
                style: TextStyle(color: c.expenseRed),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      Expanded(
        child: widget.loading
            ? const Center(child: CircularProgressIndicator())
            : widget.rows.isEmpty
                ? Center(
                    child: Text(
                      TransactionUiText.registerNoData,
                      style: TextStyle(color: c.textSecondary),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              headingRowColor: WidgetStatePropertyAll(
                                c.navy.withValues(alpha: 0.18),
                              ),
                              columns: widget.columnHeaders
                                  .map((h) => DataColumn(label: Text(h)))
                                  .toList(),
                              rows: widget.rows.map((r) {
                                final cells = widget.cellBuilder(r);
                                if (widget.onRowTap == null) {
                                  return DataRow(cells: cells);
                                }
                                return DataRow(
                                  onSelectChanged: (_) => widget.onRowTap!(r),
                                  cells: cells,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}
