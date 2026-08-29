import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/report_sync_status_service.dart';
import 'package:saccm/core/utils/pdf_print.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/reports/data/repositories/reports_repository_offline.dart';
import 'package:saccm/features/reports/presentation/services/reports_csv_export_service.dart';
import 'package:saccm/features/reports/presentation/services/reports_excel_export_service.dart';
import 'package:saccm/features/reports/presentation/services/reports_pdf_export_service.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_filter_bar.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_scroll_table.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_tab_actions.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';

class DailyBalanceTab extends StatefulWidget {
  const DailyBalanceTab({super.key, required this.repository});

  final ReportsRepository repository;

  @override
  State<DailyBalanceTab> createState() => _DailyBalanceTabState();
}

class _DailyBalanceTabState extends State<DailyBalanceTab>
    with AutomaticKeepAliveClientMixin {
  final _fmt = NumberFormat('#,##0.00');
  final _dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));
  final _csvExport = ReportsCsvExportService();
  final _excelExport = ReportsExcelExportService();
  final _pdfExport = ReportsPdfExportService();
  final _schoolDs = SchoolProfileLocalDataSourceImpl();

  bool _loading = false;
  bool _printing = false;
  bool _exportingCsv = false;
  bool _exportingExcel = false;
  String? _error;
  Map<String, dynamic>? _data;

  static const _tableColumns = [
    ReportsTableColumn(
      label: TransactionUiText.reportsDailyColCategory,
      size: ColumnSize.L,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsDailyColCash,
      numeric: true,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsDailyColBank,
      numeric: true,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsDailyColAgency,
      numeric: true,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsDailyColTotal,
      numeric: true,
      size: ColumnSize.S,
    ),
    ReportsTableColumn(
      label: TransactionUiText.reportsDailyColRemark,
      size: ColumnSize.M,
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
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncInBackground(String date) async {
    if (!mounted) return;
    if (!await LicenseMode.canSyncOnline()) return;
    ReportSyncStatusService.instance.beginSync();
    try {
      await widget.repository.syncDailyBalance(date);
      final local = await widget.repository.loadCachedDailyBalance(date) ??
          await widget.repository.loadDailyBalanceLocal(date);
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
      final cached = await widget.repository.loadCachedDailyBalance(date);
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _data = cached;
          _loading = false;
        });
        unawaited(_syncInBackground(date));
        return;
      }

      _data = await widget.repository.loadDailyBalanceLocal(date);
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    } catch (e) {
      try {
        _data = await widget.repository.loadDailyBalanceLocal(date);
        _error = null;
      } catch (_) {
        _error = '${TransactionUiText.reportsLoadFailedPrefix}: $e';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<SchoolProfile> _loadSchool() async => _schoolDs.load();

  Future<void> _printPdf() async {
    if (_printing || _data == null) return;
    setState(() => _printing = true);
    try {
      final school = await _loadSchool();
      final doc = await _pdfExport.buildDailyBalancePdf(
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

  Future<void> _exportCsv() async {
    if (_exportingCsv || _data == null) return;
    setState(() => _exportingCsv = true);
    try {
      final school = await _loadSchool();
      final outcome = await _csvExport.exportDailyBalanceCsv(
        schoolProfile: school,
        data: _data!,
        reportDate: _dateCtrl.text.trim(),
      );
      if (!mounted) return;
      AppNotificationService.instance.showSuccess(
        TransactionUiText.success,
        outcome.userMessage,
        duration: Duration(seconds: outcome.displaySeconds),
      );
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_exportingExcel || _data == null) return;
    setState(() => _exportingExcel = true);
    try {
      final school = await _loadSchool();
      final outcome = await _excelExport.exportDailyBalanceExcel(
        schoolProfile: school,
        data: _data!,
        reportDate: _dateCtrl.text.trim(),
      );
      if (!mounted) return;
      AppNotificationService.instance.showSuccess(
        TransactionUiText.success,
        outcome.userMessage,
        duration: Duration(seconds: outcome.displaySeconds),
      );
    } catch (e) {
      if (mounted) {
        AppNotificationService.instance.showError(
          TransactionUiText.error,
          toUserErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  List<Map<String, dynamic>> get _rowList {
    final rawRows = _data?['rows'];
    if (rawRows is! List) return const [];
    return rawRows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<List<ReportsTableCell>> _buildTableRows() {
    double parseM(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    final out = <List<ReportsTableCell>>[];
    for (final r in _rowList) {
      out.add(_balanceCells(r, parseM));
      final subs = r['sub_rows'];
      if (subs is List) {
        for (final s in subs) {
          out.add(_balanceCells(Map<String, dynamic>.from(s as Map), parseM,
              sub: true));
        }
      }
    }
    return out;
  }

  List<ReportsTableCell> _balanceCells(
    Map<String, dynamic> r,
    double Function(dynamic) parseM, {
    bool sub = false,
  }) {
    return [
      ReportsTableCell(r['label']?.toString() ?? '', subdued: sub, maxLines: 3),
      ReportsTableCell(_fmt.format(parseM(r['cash'])), numeric: true, subdued: sub),
      ReportsTableCell(_fmt.format(parseM(r['bank'])), numeric: true, subdued: sub),
      ReportsTableCell(_fmt.format(parseM(r['agency'])), numeric: true, subdued: sub),
      ReportsTableCell(_fmt.format(parseM(r['total'])), numeric: true, subdued: sub),
      ReportsTableCell(r['remark']?.toString() ?? '', subdued: sub, maxLines: 2),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final hasData = _data != null && _rowList.isNotEmpty;
    return Column(children: [
      ReportsDateFilterBar(
        controller: _dateCtrl,
        onSubmit: _load,
        trailing: ReportsTabActions(
          onPrintPdf: hasData ? _printPdf : null,
          onExportCsv: hasData ? _exportCsv : null,
          onExportExcel: hasData ? _exportExcel : null,
          printing: _printing,
          exportingCsv: _exportingCsv,
          exportingExcel: _exportingExcel,
          printEnabled: hasData,
          csvEnabled: hasData,
          excelEnabled: hasData,
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
    double parseM(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

    final cash = parseM(d['cash']);
    final bank = parseM(d['bank']);
    final agency = parseM(d['agency']);
    final total = parseM(d['total']);
    final bankOpening = parseM(d['bank_opening_total']);
    final cashOver = d['cash_over_limit'] == true;
    final cashLimit = double.tryParse(d['cash_limit_used']?.toString() ?? '0');

    Widget pocketCard(
            String label, double amount, Color color, IconData icon) =>
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    Text(_fmt.format(amount),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 22)),
                  ],
                ),
              ),
            ]),
          ),
        );

    return [
      if (_rowList.isNotEmpty) ...[
        Text(
          TransactionUiText.reportsDailySevenRowsTitle,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            fontSize: 14,
            fontFamily: 'Kanit',
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ReportsScrollTable(
            columns: _tableColumns,
            rows: _buildTableRows(),
            minWidth: 820,
            headingRowHeight: 48,
          ),
        ),
        if (bankOpening != 0) ...[
          const SizedBox(height: 8),
          Text(
            '${TransactionUiText.reportsBankOpeningIncludedNotePrefix} ${_fmt.format(bankOpening)} ${TransactionUiText.reportsBankOpeningIncludedNoteSuffix}',
            style: TextStyle(fontSize: 11, color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 16),
      ],
      pocketCard(TransactionUiText.reportsCashTotalLabel, cash, c.expenseRed,
          Icons.payments_outlined),
      const SizedBox(height: 8),
      pocketCard(TransactionUiText.reportsBankTotalLabel, bank, c.navy,
          Icons.account_balance_outlined),
      const SizedBox(height: 8),
      pocketCard(TransactionUiText.reportsAgencyTotalLabel, agency, c.loanAmber,
          Icons.account_balance_wallet_outlined),
      const SizedBox(height: 12),
      Card(
        color: c.iconBgIncome,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.summarize_outlined),
            const SizedBox(width: 12),
            Text(TransactionUiText.reportsGrandTotalLabel,
                style: TextStyle(color: c.textPrimary, fontSize: 14)),
            const Spacer(),
            Text(_fmt.format(total),
                style: TextStyle(
                    color: c.incomeGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ]),
        ),
      ),
      if (cashOver) ...[
        const SizedBox(height: 12),
        Card(
          color: c.expenseRed.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.warning_amber_outlined, color: c.expenseRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${TransactionUiText.reportsCashOverLimitPrefix} (${cashLimit != null ? _fmt.format(cashLimit) : ''}) ${TransactionUiText.reportsCashOverLimitSuffix}',
                  style: TextStyle(color: c.expenseRed),
                ),
              ),
            ]),
          ),
        ),
      ],
    ];
  }
}
