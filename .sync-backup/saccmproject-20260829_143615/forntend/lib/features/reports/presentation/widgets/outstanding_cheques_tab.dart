import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/report_sync_status_service.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/register/presentation/widgets/_simple_register_tab_base.dart';
import 'package:saccm/features/reports/data/repositories/reports_repository_offline.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_filter_bar.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_scroll_table.dart';

class OutstandingChequesTab extends StatefulWidget {
  const OutstandingChequesTab({
    super.key,
    required this.repository,
    required this.fiscalYearText,
  });

  final ReportsRepository repository;
  final String fiscalYearText;

  @override
  State<OutstandingChequesTab> createState() => _OutstandingChequesTabState();
}

class _OutstandingChequesTabState extends State<OutstandingChequesTab>
    with AutomaticKeepAliveClientMixin {
  final _fmt = NumberFormat('#,##0.00');
  final _dateCtrl = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  static const _columns = [
    ReportsTableColumn(label: 'วันที่', size: ColumnSize.S),
    ReportsTableColumn(label: 'เลขที่เช็ค', size: ColumnSize.S),
    ReportsTableColumn(label: 'เลขที่ใบจ่าย', size: ColumnSize.S),
    ReportsTableColumn(label: 'ธนาคาร', size: ColumnSize.M),
    ReportsTableColumn(label: 'บัญชี', size: ColumnSize.S),
    ReportsTableColumn(label: 'รายการ', size: ColumnSize.L),
    ReportsTableColumn(label: 'จำนวนเงิน', numeric: true, size: ColumnSize.S),
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

  int? get _fiscalYear =>
      int.tryParse(widget.fiscalYearText.trim()) ??
      FiscalYear.currentBuddhist();

  List<Map<String, dynamic>> get _rows {
    final list = _data?['rows'];
    if (list is! List) return const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  double get _total {
    final t = _data?['total_outstanding'];
    if (t != null) return double.tryParse(t.toString()) ?? 0;
    return _rows.fold<double>(
      0,
      (s, r) =>
          s +
          (double.tryParse(
                (r['amount'] ?? r['chequeamount'])?.toString() ?? '0',
              ) ??
              0),
    );
  }

  Future<void> _syncInBackground(String date) async {
    if (!mounted) return;
    if (!await LicenseMode.canSyncOnline()) return;
    ReportSyncStatusService.instance.beginSync();
    try {
      await widget.repository.syncOutstandingCheques(
        date: date,
        fiscalYear: _fiscalYear,
      );
      final local = await widget.repository.loadCachedOutstandingCheques(
            date: date,
            fiscalYear: _fiscalYear,
          ) ??
          await widget.repository.loadOutstandingChequesLocal(
            date: date,
            fiscalYear: _fiscalYear,
          );
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
      final cached = await widget.repository.loadCachedOutstandingCheques(
        date: date,
        fiscalYear: _fiscalYear,
      );
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _data = cached;
          _loading = false;
        });
        unawaited(_syncInBackground(date));
        return;
      }

      _data = await widget.repository.loadOutstandingChequesLocal(
        date: date,
        fiscalYear: _fiscalYear,
      );
      unawaited(_syncInBackground(date));
    } catch (e) {
      _error = '${TransactionUiText.reportsLoadFailedPrefix}: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final rows = _rows;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text(
            TransactionUiText.chequeOutstandingHint,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ),
        ReportsDateFilterBar(
          controller: _dateCtrl,
          onSubmit: _load,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.iconBgLoan,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TransactionUiText.chequeOutstandingTotalLabel,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_fmt.format(_total)} ${TransactionUiText.baht}',
                            style: TextStyle(
                              color: c.loanAmber,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          TransactionUiText.chequeOutstandingCountLabel,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${rows.length} ${TransactionUiText.items}',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                TransactionUiText.chequeOutstandingMarkInRegisterHint,
                style: TextStyle(color: c.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: scheme.primary))
              : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: c.expenseRed),
                      ),
                    )
                  : rows.isEmpty
                      ? Center(
                          child: Text(
                            TransactionUiText.noData,
                            style: TextStyle(color: c.textSecondary),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ReportsScrollTable(
                              columns: _columns,
                              rows: rows.map((r) {
                                return [
                                  ReportsTableCell(
                                    SimpleRegisterTabBase.formatThaiDate(
                                      r['docdate']?.toString(),
                                    ),
                                  ),
                                  ReportsTableCell(
                                    r['chequeno']?.toString() ?? '-',
                                  ),
                                  ReportsTableCell(
                                    r['expense_docno']?.toString() ?? '-',
                                  ),
                                  ReportsTableCell(
                                    r['bank_name']?.toString() ?? '-',
                                    maxLines: 2,
                                  ),
                                  ReportsTableCell(
                                    r['cheque_account_no']?.toString() ?? '-',
                                  ),
                                  ReportsTableCell(
                                    r['expense_detail']?.toString() ?? '',
                                    maxLines: 2,
                                  ),
                                  ReportsTableCell(
                                    SimpleRegisterTabBase.formatNumber(
                                      r['amount'] ?? r['chequeamount'],
                                    ),
                                    numeric: true,
                                  ),
                                ];
                              }).toList(),
                              minWidth: 960,
                              headingRowHeight: 48,
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}
