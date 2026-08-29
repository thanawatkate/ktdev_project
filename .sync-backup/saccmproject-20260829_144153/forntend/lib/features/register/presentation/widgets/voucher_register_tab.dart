import 'package:flutter/material.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import '_simple_register_tab_base.dart';

class VoucherRegisterTab extends StatefulWidget {
  const VoucherRegisterTab({super.key});

  @override
  State<VoucherRegisterTab> createState() => _VoucherRegisterTabState();
}

class _VoucherRegisterTabState extends State<VoucherRegisterTab>
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
      _rows = await _local.getVoucherRegister(fiscalYear: _fiscalYear);
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
      headerInfo: 'ทะเบียนคุมใบสำคัญคู่จ่าย — แสดงรายการเบิกจ่ายในปีงบประมาณ',
      columnHeaders: const [
        'วันที่',
        'เลขที่',
        'รายละเอียด',
        'ผู้รับ',
        'แหล่งงบ',
        'จำนวนเงิน',
      ],
      cellBuilder: (r) => [
        DataCell(Text(
            SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()))),
        DataCell(Text(r['docno']?.toString() ?? '-')),
        DataCell(SizedBox(
            width: 220,
            child: Text(
                r['detail']?.toString() ?? r['remark']?.toString() ?? '',
                overflow: TextOverflow.ellipsis))),
        DataCell(Text(r['receiver']?.toString() ?? '-')),
        DataCell(Text(r['budget_source_name']?.toString() ?? '-')),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['amount']))),
      ],
      csvFilePrefix: 'voucher_register',
      csvRowBuilder: (r) => [
        SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()),
        r['docno']?.toString() ?? '',
        r['detail']?.toString() ?? r['remark']?.toString() ?? '',
        r['receiver']?.toString() ?? '',
        r['budget_source_name']?.toString() ?? '',
        SimpleRegisterTabBase.formatNumber(r['amount']),
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
