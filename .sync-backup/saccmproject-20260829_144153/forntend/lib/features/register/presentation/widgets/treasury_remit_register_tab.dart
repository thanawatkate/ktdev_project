import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import '_simple_register_tab_base.dart';

/// ทะเบียนคุมรับและนำส่งเงินรายได้แผ่นดิน
///
/// คอลัมน์: วัน | ที่เอกสาร | รายการ | แหล่งเงิน | รับ | นำส่ง | คงเหลือ | หมายเหตุ
/// กรองเฉพาะรายการที่ผ่านแหล่งเงินที่อ้าง money_group "เงินรายได้แผ่นดิน"
class TreasuryRemitRegisterTab extends StatefulWidget {
  const TreasuryRemitRegisterTab({super.key});

  @override
  State<TreasuryRemitRegisterTab> createState() =>
      _TreasuryRemitRegisterTabState();
}

class _TreasuryRemitRegisterTabState extends State<TreasuryRemitRegisterTab>
    with AutomaticKeepAliveClientMixin {
  final _local = RegisterLocalDataSource();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  double _opening = 0;
  double _ending = 0;
  String? _note;
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
      _note = null;
    });
    try {
      final result = await _local.getTreasuryRemitRegister(
        fiscalYearBuddhist: _fiscalYear,
      );
      _opening = (result['opening'] as num?)?.toDouble() ?? 0;
      _ending = (result['ending'] as num?)?.toDouble() ?? 0;
      _note = result['note'] as String?;
      final lines = (result['lines'] as List?) ?? const [];
      _rows = [
        {
          'docdate': null,
          'docno': '-',
          'detail': TransactionUiText.registerOpeningBalance,
          'budget_source_name': '-',
          'received': 0.0,
          'remitted': 0.0,
          'balance': _opening,
          'remark': '',
          '_synthetic': true,
        },
        ...lines.cast<Map<String, dynamic>>(),
      ];
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
    final headerExtra = _note != null
        ? ' • $_note'
        : ' • ${TransactionUiText.registerEndingBalance}: ${SimpleRegisterTabBase.formatNumber(_ending)}';
    return SimpleRegisterTabBase(
      loading: _loading,
      error: _error,
      rows: _rows,
      headerInfo: TransactionUiText.registerTreasuryRemitHeader + headerExtra,
      columnHeaders: const [
        TransactionUiText.registerColDate,
        TransactionUiText.registerColDocNo,
        TransactionUiText.registerColDetail,
        TransactionUiText.registerColBudgetSource,
        TransactionUiText.registerColReceived,
        TransactionUiText.registerColRemitted,
        TransactionUiText.registerColBalance,
        TransactionUiText.registerColRemark,
      ],
      cellBuilder: (r) => [
        DataCell(Text(r['docdate'] == null
            ? '-'
            : SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()))),
        DataCell(Text(r['docno']?.toString() ?? '-')),
        DataCell(SizedBox(
          width: 200,
          child: Text(
            r['detail']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        )),
        DataCell(SizedBox(
          width: 160,
          child: Text(
            r['budget_source_name']?.toString() ?? '-',
            overflow: TextOverflow.ellipsis,
          ),
        )),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['received']))),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['remitted']))),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['balance']))),
        DataCell(SizedBox(
          width: 140,
          child: Text(
            r['remark']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      csvFilePrefix: 'treasury_remit_register',
      csvRowBuilder: (r) => [
        r['docdate'] == null
            ? '-'
            : SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()),
        r['docno']?.toString() ?? '',
        r['detail']?.toString() ?? '',
        r['budget_source_name']?.toString() ?? '',
        SimpleRegisterTabBase.formatNumber(r['received']),
        SimpleRegisterTabBase.formatNumber(r['remitted']),
        SimpleRegisterTabBase.formatNumber(r['balance']),
        r['remark']?.toString() ?? '',
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
