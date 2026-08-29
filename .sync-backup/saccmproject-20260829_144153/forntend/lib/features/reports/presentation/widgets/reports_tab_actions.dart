import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

enum ReportsExportFormat { csv, excel }

/// Optional print / export actions shown beside report filter bars.
class ReportsTabActions extends StatelessWidget {
  const ReportsTabActions({
    super.key,
    this.onPrintPdf,
    this.onExportCsv,
    this.onExportExcel,
    this.printing = false,
    this.exportingCsv = false,
    this.exportingExcel = false,
    this.printEnabled = true,
    this.csvEnabled = true,
    this.excelEnabled = true,
  });

  final VoidCallback? onPrintPdf;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportExcel;
  final bool printing;
  final bool exportingCsv;
  final bool exportingExcel;
  final bool printEnabled;
  final bool csvEnabled;
  final bool excelEnabled;

  bool get _exporting => exportingCsv || exportingExcel;
  bool get _hasExport => onExportCsv != null || onExportExcel != null;

  @override
  Widget build(BuildContext context) {
    if (onPrintPdf == null && !_hasExport) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPrintPdf != null)
          IconButton(
            onPressed: printing || !printEnabled ? null : onPrintPdf,
            tooltip: TransactionUiText.reportsPrintPdfTooltip,
            icon: printing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
          ),
        if (_hasExport)
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<ReportsExportFormat>(
                  tooltip: TransactionUiText.reportsExportTooltip,
                  enabled: !_exporting &&
                      ((onExportCsv != null && csvEnabled) ||
                          (onExportExcel != null && excelEnabled)),
                  onSelected: (format) {
                    switch (format) {
                      case ReportsExportFormat.csv:
                        onExportCsv?.call();
                      case ReportsExportFormat.excel:
                        onExportExcel?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onExportCsv != null)
                      PopupMenuItem(
                        value: ReportsExportFormat.csv,
                        enabled: csvEnabled,
                        child: Text(TransactionUiText.exportCsv),
                      ),
                    if (onExportExcel != null)
                      PopupMenuItem(
                        value: ReportsExportFormat.excel,
                        enabled: excelEnabled,
                        child: Text(TransactionUiText.exportExcel),
                      ),
                  ],
                  icon: const Icon(Icons.download_outlined),
                ),
      ],
    );
  }
}
