import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:saccm/config.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/expense_local_data_source.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart'
    show showAutoDismissAlert;
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '_simple_register_tab_base.dart';

class ChequeRegisterTab extends StatefulWidget {
  const ChequeRegisterTab({super.key, required this.dio});

  final Dio dio;

  @override
  State<ChequeRegisterTab> createState() => _ChequeRegisterTabState();
}

class _ChequeRegisterTabState extends State<ChequeRegisterTab>
    with AutomaticKeepAliveClientMixin {
  final _local = RegisterLocalDataSource();
  final _payLocal = ExpenseLocalDataSource();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  int _fiscalYear = FiscalYear.currentBuddhist();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isCleared(Map<String, dynamic> r) {
    final v = r['cleared_at']?.toString() ?? '';
    return v.isNotEmpty;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await _local.getChequeRegister(fiscalYear: _fiscalYear);
    } catch (e) {
      _error = e.toString();
      _rows = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markCleared(Map<String, dynamic> row) async {
    final id = row['pay_cheque_id']?.toString() ?? row['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.registerChequeMarkCleared,
        message: TransactionUiText.registerChequeMarkClearedConfirm,
        confirmText: TransactionUiText.confirm,
        confirmColor: Theme.of(ctx).colorScheme.primary,
      ),
    );
    if (ok != true || !mounted) return;

    await _payLocal.init();
    await _payLocal.markPayChequeCleared(id);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null &&
        token.isNotEmpty &&
        await LicenseMode.canSyncOnline()) {
      await ServiceLocator.instance.get<SyncService>().addPendingRequest(
            id: 'pay_cheque_clear_$id',
            method: 'PATCH',
            endpoint: '${baseurl}paycheque/$id',
            payload: jsonEncode({
              'token': token,
              'cleared_at': DateTime.now().toIso8601String(),
            }),
          );
    }

    if (!mounted) return;
    showAutoDismissAlert(
      context,
      TransactionUiText.success,
      TransactionUiText.registerChequeClearedDone,
      3,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SimpleRegisterTabBase(
      loading: _loading,
      error: _error,
      rows: _rows,
      headerInfo:
          'ทะเบียนคุมการจ่ายเช็ค — แตะแถวที่ค้างตัดเพื่อบันทึกว่าตัดบัญชีแล้ว',
      columnHeaders: const [
        'วันที่',
        'เลขที่เช็ค',
        'ธนาคาร',
        'บัญชี',
        'รายการ',
        'จำนวนเงิน',
        TransactionUiText.registerChequeStatusLabel,
      ],
      cellBuilder: (r) {
        final cleared = _isCleared(r);
        return [
          DataCell(Text(
              SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()))),
          DataCell(Text(r['chequeno']?.toString() ?? '-')),
          DataCell(Text(r['bank_name']?.toString() ?? '-')),
          DataCell(Text(r['cheque_account_no']?.toString() ?? '-')),
          DataCell(SizedBox(
              width: 200,
              child: Text(
                  r['expense_detail']?.toString() ??
                      r['remark']?.toString() ??
                      '',
                  overflow: TextOverflow.ellipsis))),
          DataCell(Text(SimpleRegisterTabBase.formatNumber(
              r['amount'] ?? r['chequeamount']))),
          DataCell(
            Text(
              cleared
                  ? TransactionUiText.registerChequeStatusCleared
                  : TransactionUiText.registerChequeStatusOutstanding,
              style: TextStyle(
                color: cleared ? Colors.green.shade700 : Colors.orange.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ];
      },
      csvFilePrefix: 'cheque_register',
      csvRowBuilder: (r) {
        final cleared = _isCleared(r);
        return [
          SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()),
          r['chequeno']?.toString() ?? '',
          r['bank_name']?.toString() ?? '',
          r['cheque_account_no']?.toString() ?? '',
          r['expense_detail']?.toString() ?? r['remark']?.toString() ?? '',
          SimpleRegisterTabBase.formatNumber(r['amount'] ?? r['chequeamount']),
          cleared
              ? TransactionUiText.registerChequeStatusCleared
              : TransactionUiText.registerChequeStatusOutstanding,
        ];
      },
      onRowTap: (r) {
        if (!_isCleared(r)) _markCleared(r);
      },
      fiscalYear: _fiscalYear,
      onChangeFiscalYear: (v) {
        setState(() => _fiscalYear = v);
        _load();
      },
      onRefresh: _load,
    );
  }
}
