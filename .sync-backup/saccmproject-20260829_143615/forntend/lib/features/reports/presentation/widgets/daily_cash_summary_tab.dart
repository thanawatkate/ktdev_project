// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/core/services/report_sync_status_service.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/reports/data/repositories/reports_repository_offline.dart';
import 'package:saccm/features/reports/presentation/widgets/reports_filter_bar.dart';

/// สรุปเงินสดรายวัน — อ่าน `report_daily_cash_summary_cache` ก่อน แล้วซิงก์เซิร์ฟเวอร์เบื้องหลัง
/// หากยังไม่มีแคช จะคำนวณจากรายการใน SQLite ชั่วคราวจนกว่าจะดึงจากเซิร์ฟเวอร์ได้
class DailyCashSummaryTab extends StatefulWidget {
  const DailyCashSummaryTab({super.key, required this.repository});

  final ReportsRepository repository;

  @override
  State<DailyCashSummaryTab> createState() => _DailyCashSummaryTabState();
}

class _DailyCashSummaryTabState extends State<DailyCashSummaryTab>
    with AutomaticKeepAliveClientMixin {
  final _fmt = NumberFormat('#,##0.00');
  final _dateCtrl = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  bool get wantKeepAlive => true;

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
      await widget.repository.syncDailyCashSummary(date);
      final local = await widget.repository.loadCachedDailyCashSummary(date) ??
          await widget.repository.loadDailyCashSummaryLocal(date);
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
      final cached = await widget.repository.loadCachedDailyCashSummary(date);
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _data = cached;
          _loading = false;
        });
        unawaited(_syncInBackground(date));
        return;
      }

      final local = await widget.repository.loadDailyCashSummaryLocal(date);
      if (!mounted) return;
      setState(() {
        _data = local;
        _loading = false;
      });
    } catch (e) {
      _error = '${TransactionUiText.reportsLoadFailedPrefix}: $e';
      if (mounted) setState(() => _data = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    return Column(
      children: [
        ReportsDateFilterBar(
          controller: _dateCtrl,
          onSubmit: _load,
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: TextStyle(color: c.expenseRed),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _data == null
                      ? Center(
                          child: Text(
                            TransactionUiText.noData,
                            style: TextStyle(color: c.textSecondary),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: _rows(c),
                        ),
        ),
      ],
    );
  }

  List<Widget> _rows(AppColors c) {
    final d = _data!;
    double p(String k) => double.tryParse(d[k]?.toString() ?? '0') ?? 0;

    Widget row(String label, double value, Color color) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      color: c.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _fmt.format(value),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return [
      Text(
        TransactionUiText.reportsDailyCashSummaryTitle,
        style: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 12),
      row(TransactionUiText.reportsDailyCashOpeningLabel, p('opening_cash'),
          c.navy),
      const SizedBox(height: 8),
      row(
        TransactionUiText.reportsDailyCashReceivedCashLabel,
        p('received_cash_today'),
        c.incomeGreen,
      ),
      const SizedBox(height: 8),
      row(
        TransactionUiText.reportsDailyCashReceivedTransferLabel,
        p('received_transfer_today'),
        c.navy,
      ),
      const SizedBox(height: 8),
      row(
        TransactionUiText.reportsDailyCashPaidTodayLabel,
        p('paid_cash_today'),
        c.expenseRed,
      ),
      const SizedBox(height: 12),
      row(
        TransactionUiText.reportsDailyCashClosingLabel,
        p('closing_cash'),
        p('closing_cash') >= 0 ? c.incomeGreen : c.expenseRed,
      ),
      const SizedBox(height: 16),
      Text(
        TransactionUiText.reportsDailyCashSummaryFootnote,
        style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35),
      ),
    ];
  }
}
