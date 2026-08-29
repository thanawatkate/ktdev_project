// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/register/data/datasources/offbudget_category_local_data_source.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/widgets/widgets.dart';

/// ทะเบียนคุมเงินนอกงบประมาณ — 13 หมวดตามคู่มือ
class OffBudgetRegisterTab extends StatefulWidget {
  const OffBudgetRegisterTab({super.key});

  @override
  State<OffBudgetRegisterTab> createState() => _OffBudgetRegisterTabState();
}

class _OffBudgetRegisterTabState extends State<OffBudgetRegisterTab>
    with AutomaticKeepAliveClientMixin {
  final _localDs = OffBudgetCategoryLocalDataSource();
  late final RegisterLocalDataSource _local = RegisterLocalDataSource();
  final _fmt = NumberFormat('#,##0.00');

  bool _loading = false;
  String? _error;
  List<Map<String, Object?>> _categories = const [];
  Map<String, Object?>? _selected;
  int _fiscalYear = FiscalYear.currentBuddhist();
  late final TextEditingController _fiscalYearCtrl;
  Map<String, dynamic>? _ledger;
  List<Map<String, dynamic>> _categorySummary = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fiscalYearCtrl = TextEditingController(text: _fiscalYear.toString());
    _loadCategories();
  }

  @override
  void dispose() {
    _fiscalYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final rows = await _localDs.listAll();
      _categories = rows;
      if (rows.isNotEmpty) {
        _selected = rows.first;
        await _loadLedger();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLedger() async {
    if (_selected == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = _selected!['code']?.toString();
      final ledgerFuture = _local.getOffBudgetLedger(
        fiscalYearBuddhist: _fiscalYear,
        code: code,
      );
      final summaryFuture = _local.getOffBudgetCategorySummary(
        fiscalYearBuddhist: _fiscalYear,
      );
      final result = await ledgerFuture;
      final summary = await summaryFuture;
      if (result.containsKey('error')) {
        _error = result['error']?.toString() ??
            TransactionUiText.registerOffBudgetLoadIncomplete;
        _ledger = null;
        _categorySummary = const [];
      } else {
        _ledger = result;
        _categorySummary = summary;
      }
    } catch (e) {
      _error = e.toString();
      _ledger = null;
      _categorySummary = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    return Column(
      children: [
        _filterBar(c),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 100,
              child: SingleChildScrollView(
                child: Text(_error!,
                    style: TextStyle(color: c.expenseRed),
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _ledger == null
                  ? _empty(c)
                  : _ledgerView(c),
        ),
      ],
    );
  }

  Widget _filterBar(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: c.cardWhite,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 2,
            child: AppLookupPickerField<String>(
              label: TransactionUiText.registerOffBudgetCategoryLabel,
              value: _selected?['code']?.toString(),
              clearable: false,
              items: _categories.map((cat) {
                final code = cat['code']?.toString() ?? '';
                final name = cat['name']?.toString() ?? '';
                return AppDropdownItem<String>(
                  value: code,
                  label: '$code - $name',
                );
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                final found =
                    _categories.firstWhere((e) => e['code']?.toString() == v);
                setState(() => _selected = found);
                _loadLedger();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 200,
            child: BuddhistYearField.picker(
              controller: _fiscalYearCtrl,
              required: false,
              maxYear: BuddhistYearField.toBuddhist(DateTime.now().year + 10),
              onChanged: (_) => _applyFiscalYearAndLoad(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filledTonal(
              tooltip: TransactionUiText.refresh,
              onPressed: _loading ? null : _applyFiscalYearAndLoad,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFiscalYearAndLoad() {
    final parsed = int.tryParse(_fiscalYearCtrl.text.trim()) ?? _fiscalYear;
    if (parsed != _fiscalYear) {
      setState(() => _fiscalYear = parsed);
    }
    _loadLedger();
  }

  Widget _empty(AppColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, size: 64, color: c.textHint),
          const SizedBox(height: 8),
          Text(TransactionUiText.registerNoData,
              style: TextStyle(color: c.textSecondary)),
        ],
      ),
    );
  }

  Widget _ledgerView(AppColors c) {
    final lines = (_ledger?['lines'] as List?) ?? const [];
    final months = (_ledger?['months'] as List?) ?? const [];
    final opening = _ledger?['opening'] as Map?;
    final ending = _ledger?['ending'] as Map?;
    final totalIn =
        double.tryParse(_ledger?['total_in']?.toString() ?? '0') ?? 0;
    final totalOut =
        double.tryParse(_ledger?['total_out']?.toString() ?? '0') ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      children: [
        _summaryStrip(c, opening, ending, totalIn, totalOut),
        if (_categorySummary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TransactionUiText.registerOffBudgetAllCategoriesTitle,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _allCategoriesTable(c),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TransactionUiText.registerMonthlySummaryHeader,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                _monthlyTable(c, months),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TransactionUiText.registerLinesHeader,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                _linesTable(c, lines),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryStrip(
      AppColors c, Map? opening, Map? ending, double totalIn, double totalOut) {
    Widget cell(String label, double value, Color color, IconData icon) =>
        Expanded(
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(label,
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(_fmt.format(value),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ),
        );

    final openingTotal = opening == null
        ? 0.0
        : (opening.values.fold<double>(
            0, (s, v) => s + (double.tryParse(v?.toString() ?? '0') ?? 0)));
    final endingTotal = ending == null
        ? 0.0
        : (ending.values.fold<double>(
            0, (s, v) => s + (double.tryParse(v?.toString() ?? '0') ?? 0)));

    return Row(children: [
      cell(TransactionUiText.registerOpeningBalance, openingTotal, c.navy,
          Icons.outbound_outlined),
      const SizedBox(width: 8),
      cell(TransactionUiText.registerTotalIn, totalIn, c.incomeGreen,
          Icons.south_rounded),
      const SizedBox(width: 8),
      cell(TransactionUiText.registerTotalOut, totalOut, c.expenseRed,
          Icons.north_rounded),
      const SizedBox(width: 8),
      cell(
          TransactionUiText.registerEndingBalance,
          endingTotal,
          endingTotal >= 0 ? c.incomeGreen : c.expenseRed,
          Icons.account_balance_wallet_outlined),
    ]);
  }

  Widget _allCategoriesTable(AppColors c) {
    return _fullWidthHorizontal(
      child: DataTable(
          headingRowColor:
              WidgetStatePropertyAll(c.navy.withValues(alpha: 0.18)),
          columns: [
            const DataColumn(label: Text(TransactionUiText.reportsColCode)),
            const DataColumn(label: Text(TransactionUiText.reportsColType)),
            const DataColumn(
                label: Text(TransactionUiText.receiveShort), numeric: true),
            const DataColumn(
                label: Text(TransactionUiText.payShort), numeric: true),
            const DataColumn(
                label: Text(TransactionUiText.registerColRunningBalanceTotal),
                numeric: true),
          ],
          rows: _categorySummary.map((row) {
            final r = Map<String, dynamic>.from(row);
            final run =
                double.tryParse(r['running_balance']?.toString() ?? '0') ?? 0;
            return DataRow(cells: [
              DataCell(Text(r['code']?.toString() ?? '')),
              DataCell(SizedBox(
                width: 260,
                child: Text(
                  r['name']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              )),
              DataCell(Text(_fmt.format(
                  double.tryParse(r['total_in']?.toString() ?? '0') ?? 0))),
              DataCell(Text(_fmt.format(
                  double.tryParse(r['total_out']?.toString() ?? '0') ?? 0))),
              DataCell(Text(
                _fmt.format(run),
                style: TextStyle(
                  color: run >= 0 ? c.incomeGreen : c.expenseRed,
                  fontWeight: FontWeight.w600,
                ),
              )),
            ]);
          }).toList()),
    );
  }

  Widget _monthlyTable(AppColors c, List months) {
    return _fullWidthHorizontal(
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(c.navy.withValues(alpha: 0.18)),
        columns: [
          const DataColumn(
              label: Text(TransactionUiText.registerMonthColMonth)),
          const DataColumn(
              label: Text(TransactionUiText.receiveShort), numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.payShort), numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.reportsDailyColCash),
              numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.reportsDailyColBank),
              numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.reportsDailyColAgency),
              numeric: true),
        ],
        rows: months.map((m) {
          final r = Map<String, dynamic>.from(m as Map);
          return DataRow(cells: [
            DataCell(Text(r['label']?.toString() ?? '')),
            DataCell(Text(_fmt.format(
                double.tryParse(r['total_in']?.toString() ?? '0') ?? 0))),
            DataCell(Text(_fmt.format(
                double.tryParse(r['total_out']?.toString() ?? '0') ?? 0))),
            DataCell(Text(_fmt
                .format(double.tryParse(r['cash']?.toString() ?? '0') ?? 0))),
            DataCell(Text(_fmt
                .format(double.tryParse(r['bank']?.toString() ?? '0') ?? 0))),
            DataCell(Text(_fmt
                .format(double.tryParse(r['agency']?.toString() ?? '0') ?? 0))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _linesTable(AppColors c, List lines) {
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(TransactionUiText.registerNoLines,
            style: TextStyle(color: c.textSecondary)),
      );
    }
    return _fullWidthHorizontal(
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(c.navy.withValues(alpha: 0.18)),
        columns: [
          const DataColumn(label: Text(TransactionUiText.registerColDate)),
          const DataColumn(label: Text(TransactionUiText.registerColDocNo)),
          const DataColumn(label: Text(TransactionUiText.registerColDetail)),
          const DataColumn(
              label: Text(TransactionUiText.receiveShort), numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.payShort), numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.registerColRunningBalanceTotal),
              numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.reportsDailyColCash),
              numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.reportsDailyColBank),
              numeric: true),
          const DataColumn(
              label: Text(TransactionUiText.reportsDailyColAgency),
              numeric: true),
          const DataColumn(label: Text(TransactionUiText.registerColRemark)),
        ],
        rows: lines.map((l) {
          final r = Map<String, dynamic>.from(l as Map);
          final dt = DateTime.tryParse(r['docdate']?.toString() ?? '');
          final dateStr = dt == null
              ? '-'
              : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${(dt.year + 543).toString().substring(2)}';
          final bc = double.tryParse(r['balance_cash']?.toString() ?? '0') ?? 0;
          final bb = double.tryParse(r['balance_bank']?.toString() ?? '0') ?? 0;
          final ba =
              double.tryParse(r['balance_agency']?.toString() ?? '0') ?? 0;
          final bTot = double.tryParse(r['balance_total']?.toString() ?? '') ??
              (bc + bb + ba);
          final rmk = (r['remark']?.toString() ?? '').trim();
          return DataRow(cells: [
            DataCell(Text(dateStr)),
            DataCell(Text(r['docno']?.toString() ?? '-')),
            DataCell(SizedBox(
              width: 320,
              child: Text(r['detail']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis),
            )),
            DataCell(Text(_fmt.format(
                double.tryParse(r['amount_in']?.toString() ?? '0') ?? 0))),
            DataCell(Text(_fmt.format(
                double.tryParse(r['amount_out']?.toString() ?? '0') ?? 0))),
            DataCell(Text(
              _fmt.format(bTot),
              style: TextStyle(
                color: bTot >= 0 ? c.incomeGreen : c.expenseRed,
                fontWeight: FontWeight.w600,
              ),
            )),
            DataCell(Text(_fmt.format(bc))),
            DataCell(Text(_fmt.format(bb))),
            DataCell(Text(_fmt.format(ba))),
            DataCell(SizedBox(
              width: 160,
              child: Text(
                rmk.isEmpty ? '—' : rmk,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _fullWidthHorizontal({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
