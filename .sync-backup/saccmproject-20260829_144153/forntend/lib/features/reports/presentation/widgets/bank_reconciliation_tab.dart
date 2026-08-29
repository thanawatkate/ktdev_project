import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/finance_compliance_service.dart';
import 'package:saccm/core/services/report_sync_status_service.dart';
import 'package:saccm/core/utils/pdf_print.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/reports/data/repositories/reports_repository_offline.dart';
import 'package:saccm/features/reports/presentation/services/reports_pdf_export_service.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_filter_bar.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_scroll_table.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_tab_actions.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/widgets/input/app_dropdown_field.dart';
import 'package:saccm/widgets/input/app_input.dart';

class BankReconciliationTab extends StatefulWidget {
  const BankReconciliationTab({super.key, required this.repository});

  final ReportsRepository repository;

  @override
  State<BankReconciliationTab> createState() => _BankReconciliationTabState();
}

class _BankReconciliationTabState extends State<BankReconciliationTab>
    with AutomaticKeepAliveClientMixin {
  final _fmt = NumberFormat('#,##0.00');
  final _dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;
  final _compliance = FinanceComplianceService();
  final _pdfExport = ReportsPdfExportService();
  final _schoolDs = SchoolProfileLocalDataSourceImpl();
  final _noteAmountCtrl = TextEditingController();
  final _noteTextCtrl = TextEditingController();
  String _noteReason = 'outstanding_cheque';
  List<Map<String, dynamic>> _notes = [];
  bool _savingNote = false;
  bool _printing = false;

  static const _accountColumns = [
    ReportsTableColumn(label: TransactionUiText.bankAccount, size: ColumnSize.M),
    ReportsTableColumn(
      label: TransactionUiText.reportsBankAccountNumberCol,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsBankOpeningLabel,
      numeric: true,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsBankInLabel,
      numeric: true,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsBankOutLabel,
      numeric: true,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsBankBookBalanceLabel,
      numeric: true,
      size: ColumnSize.S,
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteAmountCtrl.dispose();
    _noteTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes(String date) async {
    final rows = await _compliance.listReconciliationNotes(date);
    if (mounted) setState(() => _notes = rows);
  }

  Future<void> _saveNote() async {
    final date = _dateCtrl.text.trim();
    final amt = double.tryParse(_noteAmountCtrl.text.replaceAll(',', '')) ?? 0;
    setState(() => _savingNote = true);
    final err = await _compliance.saveReconciliationNote(
      asOfDate: date,
      reasonCode: _noteReason,
      amount: amt,
      note: _noteTextCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _savingNote = false);
    if (err != null) {
      AppNotificationService.instance.showError(TransactionUiText.error, err);
    } else {
      AppNotificationService.instance.showSuccess(
        TransactionUiText.success,
        TransactionUiText.bankReconNoteSaved,
      );
      _noteAmountCtrl.clear();
      _noteTextCtrl.clear();
      await _loadNotes(date);
    }
  }

  Future<void> _syncInBackground(String date) async {
    if (!mounted) return;
    if (!await LicenseMode.canSyncOnline()) return;
    ReportSyncStatusService.instance.beginSync();
    try {
      await widget.repository.syncBankReconciliation(date);
      final local =
          await widget.repository.loadCachedBankReconciliation(date) ??
              await widget.repository.loadBankReconciliationLocal(date);
      if (!mounted) return;
      setState(() {
        _data = local;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showWarning(
          TransactionUiText.syncWarningNotification,
          toUserErrorMessage(e),
        );
      }
    } finally {
      ReportSyncStatusService.instance.endSync();
    }
  }

  Future<void> _load() async {
    final date = _dateCtrl.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cached = await widget.repository.loadCachedBankReconciliation(date);
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _data = cached;
          _loading = false;
        });
        unawaited(_loadNotes(date));
        unawaited(_syncInBackground(date));
        return;
      }

      _data = await widget.repository.loadBankReconciliationLocal(date);
      if (!mounted) return;
      setState(() => _loading = false);
      await _loadNotes(date);
      return;
    } catch (e) {
      try {
        _data = await widget.repository.loadBankReconciliationLocal(date);
        _error = null;
      } catch (_) {
        _error = '${TransactionUiText.reportsLoadFailedPrefix}: $e';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _printPdf() async {
    if (_printing || _data == null) return;
    setState(() => _printing = true);
    try {
      final school = await _schoolDs.load();
      final doc = await _pdfExport.buildBankReconciliationPdf(
        schoolProfile: school,
        data: _data!,
        reportDate: _dateCtrl.text.trim(),
      );
      if (!mounted) return;
      final outcome = await printPdfBytes(
        context: context,
        bytes: doc.bytes,
        filename: doc.filename,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pdfPrintOutcomeMessage(outcome))),
      );
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    return Column(children: [
      ReportsDateFilterBar(
        controller: _dateCtrl,
        onSubmit: _load,
        trailing: ReportsTabActions(
          onPrintPdf: _data != null ? _printPdf : null,
          printing: _printing,
          printEnabled: _data != null,
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!, style: TextStyle(color: c.expenseRed)))
                : _data == null
                    ? Center(
                        child: Text(TransactionUiText.noData,
                            style: TextStyle(color: c.textSecondary)))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: _buildBody(c),
                      ),
      ),
    ]);
  }

  List<Widget> _buildBody(AppColors c) {
    final d = _data!;
    final accounts = (d['accounts'] as List?) ?? const [];
    final unallocated = d['unallocated_bank_movements'] is Map
        ? Map<String, dynamic>.from(d['unallocated_bank_movements'] as Map)
        : null;
    final opening = double.tryParse(d['total_opening']?.toString() ?? '0') ?? 0;
    final inBank = double.tryParse(d['total_in_bank']?.toString() ?? '0') ?? 0;
    final outBank =
        double.tryParse(d['total_out_bank']?.toString() ?? '0') ?? 0;
    final book = double.tryParse(d['book_balance']?.toString() ?? '0') ?? 0;
    final cheque =
        double.tryParse(d['outstanding_cheque_total']?.toString() ?? '0') ?? 0;
    final reconciled =
        double.tryParse(d['reconciled_statement_balance']?.toString() ?? '0') ??
            0;

    Widget kv(String k, double v, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(k, style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const Spacer(),
            Text(_fmt.format(v),
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ]),
        );

    return [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(TransactionUiText.reportsBankSummaryTitle,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const Divider(),
              kv(TransactionUiText.reportsBankOpeningLabel, opening,
                  c.textPrimary),
              kv(TransactionUiText.reportsBankInLabel, inBank, c.incomeGreen),
              kv(TransactionUiText.reportsBankOutLabel, outBank, c.expenseRed),
              const Divider(),
              kv(TransactionUiText.reportsBankBookBalanceLabel, book, c.navy),
              kv(TransactionUiText.reportsBankOutstandingChequeLabel, cheque,
                  c.loanAmber),
              const Divider(),
              kv(TransactionUiText.reportsBankStatementLabel, reconciled,
                  c.incomeGreen),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(TransactionUiText.reportsBankAccountsTitle,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text(TransactionUiText.reportsBankAccountSourceRule,
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
              Text(TransactionUiText.reportsBankPerAccountBookHint,
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
              const Divider(),
              if (accounts.isEmpty)
                Text(TransactionUiText.reportsNoBankAccounts,
                    style: TextStyle(color: c.textSecondary))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ReportsScrollTable(
                    columns: _accountColumns,
                    rows: accounts.map((a) {
                      final m = Map<String, dynamic>.from(a as Map);
                      double v(dynamic key) =>
                          double.tryParse(m[key]?.toString() ?? '0') ?? 0;
                      return [
                        ReportsTableCell(
                          m['bank_name']?.toString() ??
                              TransactionUiText.unspecified,
                          maxLines: 2,
                        ),
                        ReportsTableCell(
                          m['accountnumber']?.toString() ??
                              TransactionUiText.unspecified,
                        ),
                        ReportsTableCell(
                          _fmt.format(v('opening_balance')),
                          numeric: true,
                        ),
                        ReportsTableCell(
                          _fmt.format(v('total_in_bank')),
                          numeric: true,
                        ),
                        ReportsTableCell(
                          _fmt.format(v('total_out_bank')),
                          numeric: true,
                        ),
                        ReportsTableCell(
                          _fmt.format(v('book_balance')),
                          numeric: true,
                        ),
                      ];
                    }).toList(),
                    minWidth: 900,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (unallocated != null &&
          ((double.tryParse(unallocated['total_in_bank']?.toString() ?? '0') ??
                      0) >
                  0 ||
              (double.tryParse(
                          unallocated['total_out_bank']?.toString() ?? '0') ??
                      0) >
                  0)) ...[
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TransactionUiText.reportsBankUnallocatedTitle,
                    style: TextStyle(
                        color: c.loanAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(TransactionUiText.reportsBankUnallocatedSubtitle,
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
                const Divider(),
                kv(
                    TransactionUiText.reportsBankInLabel,
                    double.tryParse(
                            unallocated['total_in_bank']?.toString() ?? '0') ??
                        0,
                    c.incomeGreen),
                kv(
                    TransactionUiText.reportsBankOutLabel,
                    double.tryParse(
                            unallocated['total_out_bank']?.toString() ?? '0') ??
                        0,
                    c.expenseRed),
                kv(
                    TransactionUiText.reportsBankUnallocatedNetLabel,
                    double.tryParse(
                            unallocated['net_movement']?.toString() ?? '0') ??
                        0,
                    c.textPrimary),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TransactionUiText.bankReconNoteTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              AppDropdownField<String>(
                label: TransactionUiText.bankReconNoteReason,
                value: _noteReason,
                items: const [
                  AppDropdownItem(
                    value: 'outstanding_cheque',
                    label: TransactionUiText.bankReconReasonOutstandingCheque,
                  ),
                  AppDropdownItem(
                    value: 'transfer_pending',
                    label: TransactionUiText.bankReconReasonTransferPending,
                  ),
                  AppDropdownItem(
                    value: 'deposit_pending',
                    label: TransactionUiText.bankReconReasonDepositPending,
                  ),
                  AppDropdownItem(
                    value: 'fee_adjustment',
                    label: TransactionUiText.bankReconReasonFeeAdjustment,
                  ),
                  AppDropdownItem(
                    value: 'other',
                    label: TransactionUiText.bankReconReasonOther,
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _noteReason = v);
                },
              ),
              const SizedBox(height: 8),
              AppInput(
                label: TransactionUiText.bankReconNoteAmount,
                controller: _noteAmountCtrl,
                action: const AppInputAction.number(allowDecimal: true),
              ),
              const SizedBox(height: 8),
              AppInput(
                label: TransactionUiText.dailyClosingNoteHint,
                controller: _noteTextCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _savingNote ? null : _saveNote,
                child: Text(TransactionUiText.save),
              ),
              if (_notes.isNotEmpty) ...[
                const Divider(height: 24),
                ..._notes.map((n) {
                  final code = n['reason_code']?.toString() ?? '';
                  final amt =
                      double.tryParse(n['amount']?.toString() ?? '0') ?? 0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(code),
                    trailing: Text(_fmt.format(amt)),
                    subtitle:
                        n['note'] != null ? Text(n['note'].toString()) : null,
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}
