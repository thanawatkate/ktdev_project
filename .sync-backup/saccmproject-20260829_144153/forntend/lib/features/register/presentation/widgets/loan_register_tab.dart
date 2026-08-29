import 'package:flutter/material.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import '_simple_register_tab_base.dart';

class LoanRegisterTab extends StatefulWidget {
  const LoanRegisterTab({super.key});

  @override
  State<LoanRegisterTab> createState() => _LoanRegisterTabState();
}

class _LoanRegisterTabState extends State<LoanRegisterTab>
    with AutomaticKeepAliveClientMixin {
  final _local = RegisterLocalDataSource();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await _local.getLoanRegister(fiscalYear: _fiscalYear);
    } catch (e) {
      _error = e.toString();
      _rows = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SimpleRegisterTabBase(
      loading: _loading,
      error: _error,
      rows: _rows,
      headerInfo: 'ทะเบียนคุมสัญญายืมเงิน — แสดงสัญญายืมและยอดคงค้าง',
      columnHeaders: const [
        'วันที่ยืม',
        'เลขที่',
        'ผู้ยืม',
        'จำนวนเงิน',
        'ยอดคืน',
        'คงเหลือ',
        'กำหนดคืน',
      ],
      cellBuilder: (r) => [
        DataCell(Text(
            SimpleRegisterTabBase.formatThaiDate(r['loandate']?.toString()))),
        DataCell(Text(r['docno']?.toString() ?? '-')),
        DataCell(Text(r['borrower']?.toString() ?? '-')),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['loan_amount']))),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['repay_total']))),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['outstanding']))),
        DataCell(Text(
            SimpleRegisterTabBase.formatThaiDate(r['duedate']?.toString()))),
      ],
      csvFilePrefix: 'loan_register',
      csvRowBuilder: (r) => [
        SimpleRegisterTabBase.formatThaiDate(r['loandate']?.toString()),
        r['docno']?.toString() ?? '',
        r['borrower']?.toString() ?? '',
        SimpleRegisterTabBase.formatNumber(r['loan_amount']),
        SimpleRegisterTabBase.formatNumber(r['repay_total']),
        SimpleRegisterTabBase.formatNumber(r['outstanding']),
        SimpleRegisterTabBase.formatThaiDate(r['duedate']?.toString()),
      ],
      fiscalYear: _fiscalYear,
      onChangeFiscalYear: (v) {
        setState(() => _fiscalYear = v);
        _load();
      },
      onRefresh: _load,
    );
  }
}
