import 'package:flutter/material.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import '_simple_register_tab_base.dart';

class EvidenceRegisterTab extends StatefulWidget {
  const EvidenceRegisterTab({super.key});

  @override
  State<EvidenceRegisterTab> createState() => _EvidenceRegisterTabState();
}

class _EvidenceRegisterTabState extends State<EvidenceRegisterTab>
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
      _rows = await _local.getEvidenceRegister(fiscalYear: _fiscalYear);
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
      headerInfo: 'ทะเบียนคุมหลักฐานขอเบิก — แสดงคำขอเบิกในปีงบประมาณ',
      columnHeaders: const [
        'วันที่',
        'เลขที่',
        'รายละเอียด',
        'แหล่งงบ',
        'จำนวนเงิน',
        'สถานะอนุมัติ',
      ],
      cellBuilder: (r) => [
        DataCell(Text(
            SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()))),
        DataCell(Text(r['docno']?.toString() ?? '-')),
        DataCell(SizedBox(
            width: 220,
            child: Text(r['detail']?.toString() ?? '',
                overflow: TextOverflow.ellipsis))),
        DataCell(Text(r['budget_source_name']?.toString() ?? '-')),
        DataCell(Text(SimpleRegisterTabBase.formatNumber(r['amount']))),
        DataCell(Text(r['approval_status']?.toString() ?? '-')),
      ],
      csvFilePrefix: 'evidence_register',
      csvRowBuilder: (r) => [
        SimpleRegisterTabBase.formatThaiDate(r['docdate']?.toString()),
        r['docno']?.toString() ?? '',
        r['detail']?.toString() ?? '',
        r['budget_source_name']?.toString() ?? '',
        SimpleRegisterTabBase.formatNumber(r['amount']),
        r['approval_status']?.toString() ?? '',
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
