import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import '_simple_register_tab_base.dart';

/// สมุดคู่ฝาก (ส่วนราชการผู้เบิก)
///
/// คอลัมน์: วัน เดือน ปี | ที่เอกสาร | ฝาก | ถอน | คงเหลือ | ผู้รับฝาก/นำฝาก | หมายเหตุ
/// แสดงเฉพาะรายการที่ pocket=agency (เงินฝากส่วนราชการผู้เบิก)
class AgencyDepositRegisterTab extends StatefulWidget {
  const AgencyDepositRegisterTab({super.key});

  @override
  State<AgencyDepositRegisterTab> createState() =>
      _AgencyDepositRegisterTabState();
}

class _AgencyDepositRegisterTabState extends State<AgencyDepositRegisterTab>
    with AutomaticKeepAliveClientMixin {
  final _local = RegisterLocalDataSource();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  double _opening = 0;
  double _ending = 0;
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
      final result = await _local.getAgencyDepositRegister(
        fiscalYearBuddhist: _fiscalYear,
      );
      _opening = (result['opening'] as num?)?.toDouble() ?? 0;
      _ending = (result['ending'] as num?)?.toDouble() ?? 0;
      final lines = (result['lines'] as List?) ?? const [];
      _rows = [
        {
          'docdate': null,
          'docno': '-',
          'deposit': 0.0,
          'withdraw': 0.0,
          'balance': _opening,
          'party_name': '-',
          'remark': TransactionUiText.registerOpeningBalance,
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
    return SimpleRegisterTabBase(
      loading: _loading,
      error: _error,
      rows: _rows,
      headerInfo:
          '${TransactionUiText.registerAgencyDepositHeader} • ${TransactionUiText.registerEndingBalance}: ${SimpleRegisterTabBase.formatNumber(_ending)}',
      columnHeaders: const [
        TransactionUiText.registerColDate,
        TransactionUiText.registerColDocNo,
        TransactionUiText.registerColDeposit,
        TransactionUiText.registerColWithdraw,
        TransactionUiText.registerColBalance,
        TransactionUiText.registerColParty,
        TransactionUiText.registerColRemark,
      ],
      cellBuilder: (r) => [
        DataCell(Text(r['docdate'] == null
            ? '-'
            : SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()))),
        DataCell(Text(r['docno']?.toString() ?? '-')),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['deposit']))),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['withdraw']))),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['balance']))),
        DataCell(SizedBox(
          width: 160,
          child: Text(
            r['party_name']?.toString() ?? '-',
            overflow: TextOverflow.ellipsis,
          ),
        )),
        DataCell(SizedBox(
          width: 160,
          child: Text(
            r['remark']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      csvFilePrefix: 'agency_deposit_register',
      csvRowBuilder: (r) => [
        r['docdate'] == null
            ? '-'
            : SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()),
        r['docno']?.toString() ?? '',
        SimpleRegisterTabBase.formatNumber(r['deposit']),
        SimpleRegisterTabBase.formatNumber(r['withdraw']),
        SimpleRegisterTabBase.formatNumber(r['balance']),
        r['party_name']?.toString() ?? '',
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
