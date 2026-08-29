import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/platform/local_file_ops.dart';
import 'package:saccm/features/register/presentation/widgets/_simple_register_tab_base.dart';

class DepositRegisterCsvExportOutcome {
  const DepositRegisterCsvExportOutcome({required this.userMessage});

  final String userMessage;
}

/// ส่งออกทะเบียนเงินประกัน/ภาษีหัก ณ ที่จ่ายเป็น CSV
class DepositRegisterCsvExportService {
  DepositRegisterCsvExportService({NumberFormat? numberFormat})
      : _fmt = numberFormat ?? NumberFormat('#,##0.00');

  final NumberFormat _fmt;

  String _csvEscape(String value) => '"${value.replaceAll('"', '""')}"';

  String buildCsv({
    required List<Map<String, dynamic>> rows,
    required String Function(String? raw) typeLabel,
    required String Function(String raw) statusLabel,
  }) {
    final lines = <String>[TransactionUiText.registerDepositCsvHeader];
    for (final r in rows) {
      lines.add([
        _csvEscape(
            SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString())),
        _csvEscape(r['docno']?.toString() ?? ''),
        _csvEscape(typeLabel(r['deposit_type']?.toString())),
        _csvEscape(
            _fmt.format(double.tryParse(r['amount']?.toString() ?? '0') ?? 0)),
        _csvEscape(
          r['party_name']?.toString() ??
              r['party_name_snapshot']?.toString() ??
              '',
        ),
        _csvEscape(r['contract_no']?.toString() ?? ''),
        _csvEscape(
            SimpleRegisterTabBase.formatThaiDate(r['due_date']?.toString())),
        _csvEscape(statusLabel(r['status']?.toString() ?? '')),
        _csvEscape(r['income_docno']?.toString() ?? ''),
        _csvEscape(r['expense_docno']?.toString() ?? ''),
      ].join(','));
    }
    return lines.join('\n');
  }

  Future<DepositRegisterCsvExportOutcome> export({
    required List<Map<String, dynamic>> rows,
    required String Function(String? raw) typeLabel,
    required String Function(String raw) statusLabel,
  }) async {
    if (rows.isEmpty) {
      return const DepositRegisterCsvExportOutcome(
        userMessage: TransactionUiText.registerNoData,
      );
    }
    final csv =
        buildCsv(rows: rows, typeLabel: typeLabel, statusLabel: statusLabel);
    await Clipboard.setData(ClipboardData(text: csv));

    if (supportsDesktopFileExport) {
      final file = await writeTextFileToDocuments(
        filename:
            'deposit_register_${DateTime.now().millisecondsSinceEpoch}.csv',
        content: csv,
      );
      if (file != null) {
        return DepositRegisterCsvExportOutcome(
          userMessage:
              '${TransactionUiText.registerDepositCsvExportSuccess}\n${file.path}',
        );
      }
    }
    return const DepositRegisterCsvExportOutcome(
      userMessage: TransactionUiText.registerDepositCsvExportSuccess,
    );
  }
}
