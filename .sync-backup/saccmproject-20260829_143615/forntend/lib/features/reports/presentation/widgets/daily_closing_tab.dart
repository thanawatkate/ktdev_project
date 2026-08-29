// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/finance_compliance_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/features/reports/data/repositories/reports_repository_offline.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_filter_bar.dart';
import 'package:saccm/widgets/input/app_input.dart';

class DailyClosingTab extends StatefulWidget {
  const DailyClosingTab({
    super.key,
    required this.repository,
  });

  final ReportsRepository repository;

  @override
  State<DailyClosingTab> createState() => _DailyClosingTabState();
}

class _DailyClosingTabState extends State<DailyClosingTab>
    with AutomaticKeepAliveClientMixin {
  final _fmt = NumberFormat('#,##0.00');
  final _dateCtrl = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _noteCtrl = TextEditingController();
  late final _compliance = FinanceComplianceService(
    syncService: ServiceLocator.instance.get<SyncService>(),
  );
  bool _loading = false;
  bool _closing = false;
  Map<String, dynamic>? _balance;
  bool _isClosed = false;
  List<Map<String, dynamic>> _history = [];

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
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final date = _dateCtrl.text.trim();
    setState(() => _loading = true);
    try {
      final bal = await widget.repository.loadCachedDailyBalance(date) ??
          await widget.repository.loadDailyBalanceLocal(date);
      final closed = await _compliance.isDayClosed(date);
      final hist = await _compliance.listRecentClosings(limit: 8);
      if (!mounted) return;
      setState(() {
        _balance = bal;
        _isClosed = closed;
        _history = hist;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeDay() async {
    if (_closing || _isClosed) return;
    if (_balance?['cash_over_limit'] == true) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.dailyClosingCashOverBlock,
      );
      return;
    }
    setState(() => _closing = true);
    final err = await _compliance.closeDay(
      date: _dateCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      snapshot: _balance,
    );
    if (!mounted) return;
    setState(() => _closing = false);
    if (err != null) {
      AppNotificationService.instance.showError(TransactionUiText.error, err);
    } else {
      AppNotificationService.instance.showSuccess(
        TransactionUiText.success,
        TransactionUiText.dailyClosingSuccess,
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ReportsDateFilterBar(controller: _dateCtrl, onSubmit: _load),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isClosed)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.incomeGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: c.incomeGreen.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: c.incomeGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  TransactionUiText.dailyClosingAlreadyClosed,
                                  style: TextStyle(
                                    color: c.incomeGreen,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Kanit',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_balance != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          TransactionUiText.dailyClosingTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            fontFamily: 'Kanit',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _kv(c, 'เงินสด', _balance!['cash'], c.incomeGreen),
                        _kv(c, 'เงินฝากธนาคาร', _balance!['bank'], c.navy),
                        _kv(c, 'ส่วนราชการผู้เบิก', _balance!['agency'],
                            c.loanAmber),
                        _kv(c, TransactionUiText.totalBalance,
                            _balance!['total'], scheme.primary),
                        if (_balance!['cash_over_limit'] == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              TransactionUiText.dailyClosingCashOverBlock,
                              style:
                                  TextStyle(color: c.expenseRed, fontSize: 12),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      AppInput(
                        label: TransactionUiText.dailyClosingNoteHint,
                        controller: _noteCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _closing || _isClosed ? null : _closeDay,
                        icon: _closing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_clock_outlined),
                        label: Text(TransactionUiText.dailyClosingAction),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        TransactionUiText.dailyClosingHistoryTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_history.isEmpty)
                        Text(
                          TransactionUiText.noData,
                          style: TextStyle(color: c.textSecondary),
                        )
                      else
                        ..._history.map((row) {
                          final d = row['close_date']?.toString() ?? '';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.event_available,
                                color: c.incomeGreen, size: 20),
                            title:
                                Text(d, style: TextStyle(color: c.textPrimary)),
                            subtitle: row['note'] != null &&
                                    row['note'].toString().trim().isNotEmpty
                                ? Text(row['note'].toString())
                                : null,
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _kv(AppColors c, String label, dynamic value, Color color) {
    final n = double.tryParse(value?.toString() ?? '0') ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: c.textSecondary)),
          Text(
            '${_fmt.format(n)} ${TransactionUiText.baht}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
