// ignore_for_file: use_build_context_synchronously
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/core/utils/pdf_print.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/forms/data/datasources/form_remote_data_source.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/features/expense/presentation/providers/expense_provider.dart';
import 'package:saccm/features/income/presentation/providers/income_provider.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/features/register/presentation/pages/deposit_guarantee_add_page.dart';
import 'package:saccm/features/register/presentation/pages/deposit_guarantee_detail_page.dart';
import 'package:saccm/features/register/presentation/pages/deposit_guarantee_settle_page.dart';
import 'package:saccm/features/register/presentation/services/deposit_register_csv_export_service.dart';
import 'package:saccm/widgets/widgets.dart';
import '_simple_register_tab_base.dart';

/// แท็บเงินประกันสัญญา / เงินภาษีหัก ณ ที่จ่าย
class DepositGuaranteeTab extends StatefulWidget {
  const DepositGuaranteeTab({
    super.key,
    required this.dio,
    this.fixedDepositType,
  });
  final Dio dio;

  /// กรองประเภทคงที่ (contract_guarantee / withholding_tax) — null = ทั้งหมด
  final String? fixedDepositType;

  @override
  State<DepositGuaranteeTab> createState() => _DepositGuaranteeTabState();
}

class _DepositGuaranteeTabState extends State<DepositGuaranteeTab>
    with AutomaticKeepAliveClientMixin {
  static const int _dueSoonDays = 30;

  final _local = RegisterLocalDataSource();
  final _csvExport = DepositRegisterCsvExportService();
  bool _loading = false;
  bool _exportingCsv = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _dueSoonRows = const [];
  int _fiscalYear = FiscalYear.currentBuddhist();
  String _filterStatus = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> get _displayRows {
    if (_filterStatus != 'due_soon') return _rows;
    return _rows.where(_isDueSoonRow).toList();
  }

  bool _isDueSoonRow(Map<String, dynamic> r) {
    if (r['status']?.toString() != 'holding') return false;
    final days = _daysUntilDue(r['due_date']?.toString());
    if (days == null) return false;
    return days < 0 || days <= _dueSoonDays;
  }

  static int? _daysUntilDue(String? raw) {
    final due = DateTime.tryParse(raw ?? '');
    if (due == null) return null;
    final today = DateTime.now();
    final dueOnly = DateTime(due.year, due.month, due.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    return dueOnly.difference(todayOnly).inDays;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _local.listDeposits(
        fiscalYear: _fiscalYear.toString(),
        depositType: widget.fixedDepositType,
        status: _filterStatus == 'due_soon' || _filterStatus == 'all'
            ? null
            : _filterStatus,
      );
      final dueSoon = await _local.listDepositsDueSoon(
        withinDays: _dueSoonDays,
        fiscalYear: _fiscalYear.toString(),
        depositType: widget.fixedDepositType,
      );
      _rows = rows;
      _dueSoonRows = dueSoon;
    } catch (e) {
      _error = e.toString();
      _rows = const [];
      _dueSoonRows = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showReconciliation() async {
    final c = AppColors.of(context);
    try {
      final results = await Future.wait([
        _local.getDepositReconciliation(
          depositType: 'contract_guarantee',
        ),
        _local.getDepositReconciliation(
          depositType: 'withholding_tax',
        ),
      ]);
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          child: AdaptiveContentSheet(
            title: TransactionUiText.registerDepositReconcileTitle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                AppTheme.sp16,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _reconcileBlock(
                      c,
                      TransactionUiText.registerDepositTypeContractGuarantee,
                      results[0],
                    ),
                    const SizedBox(height: 12),
                    _reconcileBlock(
                      c,
                      TransactionUiText.registerDepositTypeWithholdingTax,
                      results[1],
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton.primary(
                        label: TransactionUiText.close,
                        fullWidth: false,
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${TransactionUiText.createFailed}: $e')),
      );
    }
  }

  Widget _reconcileBlock(
    AppColors c,
    String title,
    Map<String, dynamic> res,
  ) {
    final data = res['data'];
    if (res['status'] != 'successfully' || data is! Map) {
      return Text('$title: ${res['message'] ?? '-'}');
    }
    final m = Map<String, dynamic>.from(data);
    final balanced = m['balanced'] == true;
    final reg = m['register_holding_total'];
    final led = m['ledger_net_total'];
    final diff = m['difference'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: balanced ? Colors.green.shade300 : Colors.orange.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontFamily: 'Kanit',
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            balanced
                ? TransactionUiText.registerDepositReconcileBalanced
                : TransactionUiText.registerDepositReconcileUnbalanced,
            style: TextStyle(
              color: balanced ? Colors.green.shade800 : Colors.orange.shade900,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${TransactionUiText.registerDepositReconcileRegister}: '
            '${SimpleRegisterTabBase.formatNumber(reg)}',
            style: const TextStyle(fontFamily: 'Kanit'),
          ),
          Text(
            '${TransactionUiText.registerDepositReconcileLedger}: '
            '${SimpleRegisterTabBase.formatNumber(led)}',
            style: const TextStyle(fontFamily: 'Kanit'),
          ),
          Text(
            '${TransactionUiText.registerDepositReconcileDiff}: '
            '${SimpleRegisterTabBase.formatNumber(diff)}',
            style: const TextStyle(fontFamily: 'Kanit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDueSoonBanner(AppColors c) {
    if (_dueSoonRows.isEmpty) return const SizedBox.shrink();

    var overdue = 0;
    var upcoming = 0;
    for (final r in _dueSoonRows) {
      if (r['is_overdue'] == true) {
        overdue++;
      } else {
        upcoming++;
      }
    }

    return Material(
      color: Colors.orange.shade50,
      child: InkWell(
        onTap: () {
          setState(() => _filterStatus = 'due_soon');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.notification_important_outlined,
                  color: Colors.orange.shade800, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TransactionUiText.registerDepositDueSoonBannerTitle,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      '${TransactionUiText.registerDepositDueSoonBannerOverdue}: $overdue · '
                      '${TransactionUiText.registerDepositDueSoonBannerUpcoming}: $upcoming',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dueDateCell(AppColors c, Map<String, dynamic> r) {
    final raw = r['due_date']?.toString();
    final days = _daysUntilDue(raw);
    final label = SimpleRegisterTabBase.formatThaiDate(raw);
    if (days == null || r['status']?.toString() != 'holding') {
      return Text(label);
    }

    Color? bg;
    Color? fg;
    String? suffix;
    if (days < 0) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade900;
      suffix = '${TransactionUiText.registerDepositDueSoonDaysOver} ${-days} '
          '${TransactionUiText.registerDepositDueSoonDayUnit}';
    } else if (days <= _dueSoonDays) {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade900;
      suffix = '${TransactionUiText.registerDepositDueSoonDaysLeft} $days '
          '${TransactionUiText.registerDepositDueSoonDayUnit}';
    }

    if (bg == null) return Text(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: fg, fontFamily: 'Kanit')),
          Text(
            suffix!,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontFamily: 'Kanit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerDocsCell(Map<String, dynamic> r) {
    final inDoc = r['income_docno']?.toString().trim();
    final outDoc = r['expense_docno']?.toString().trim();
    final inLabel = inDoc == null || inDoc.isEmpty
        ? TransactionUiText.registerDepositNoIncomeDoc
        : inDoc;
    final outLabel = outDoc == null || outDoc.isEmpty
        ? TransactionUiText.registerDepositNoIncomeDoc
        : outDoc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${TransactionUiText.registerDepositColIncomeDoc}: $inLabel',
          style: const TextStyle(fontFamily: 'Kanit', fontSize: 12),
        ),
        Text(
          '${TransactionUiText.registerDepositColExpenseDoc}: $outLabel',
          style: const TextStyle(fontFamily: 'Kanit', fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _openAddPage() async {
    final ok = await SingleOpenNavigation.push<bool>(
      context,
      key: 'deposit_guarantee.add',
      route: MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => IncomeProvider(monneyType: [], incomeType: []),
          child: DepositGuaranteeAddPage(dio: widget.dio),
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _openDetailPage(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await SingleOpenNavigation.push<bool>(
      context,
      key: 'deposit_guarantee.detail',
      route: MaterialPageRoute(
        builder: (_) => DepositGuaranteeDetailPage(
          dio: widget.dio,
          depositId: id,
          initialRow: row,
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<PdfPrintDocument> _buildDepositRegisterPrintDocument() async {
    final school = await SchoolProfileLocalDataSourceImpl().load();
    final ds = FormRemoteDataSource();
    final bytes = await ds.generate('deposit-register', {
      'school_name': school.name,
      'fiscal_year': _fiscalYear.toString(),
      if (widget.fixedDepositType != null)
        'deposit_type': widget.fixedDepositType,
      'rows': _rows,
    });
    return PdfPrintDocument(
      bytes: bytes,
      filename: 'deposit_register_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv || _rows.isEmpty) return;
    setState(() => _exportingCsv = true);
    try {
      final outcome = await _csvExport.export(
        rows: _rows,
        typeLabel: _typeLabel,
        statusLabel: _statusLabel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.userMessage,
            style: const TextStyle(fontFamily: 'Kanit'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _openSettlePage(Map<String, dynamic> row) async {
    final ok = await SingleOpenNavigation.push<bool>(
      context,
      key: 'deposit_guarantee.settle',
      route: MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ExpenseProvider(),
          child: DepositGuaranteeSettlePage(
            dio: widget.dio,
            deposit: row,
          ),
        ),
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<SimpleAuthProvider>();
    final canCreate = auth.can(PermissionKey.registerDepositCreate);
    final canSettlePerm = auth.can(PermissionKey.registerDepositSettle);
    final c = AppColors.of(context);
    final filterLabelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: 'Kanit',
        );

    return Stack(children: [
      Column(children: [
        _buildDueSoonBanner(c),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: c.cardWhite,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                TransactionUiText.registerDepositFilterLabel,
                style: filterLabelStyle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropdownField<String>(
                  density: AppDropdownDensity.compact,
                  value: _filterStatus,
                  items: const [
                    AppDropdownItem(
                      value: 'all',
                      label: TransactionUiText.registerDepositStatusAll,
                    ),
                    AppDropdownItem(
                      value: 'due_soon',
                      label: TransactionUiText.registerDepositFilterDueSoon,
                    ),
                    AppDropdownItem(
                      value: 'holding',
                      label: TransactionUiText.registerDepositStatusHolding,
                    ),
                    AppDropdownItem(
                      value: 'returned',
                      label: TransactionUiText.registerDepositStatusReturned,
                    ),
                    AppDropdownItem(
                      value: 'submitted',
                      label: TransactionUiText.registerDepositStatusSubmitted,
                    ),
                    AppDropdownItem(
                      value: 'forfeited',
                      label: TransactionUiText.registerDepositStatusForfeited,
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _filterStatus = v ?? 'all');
                    if (v != 'due_soon') _load();
                  },
                ),
              ),
              AppPdfPrintIconButton(
                enabled: !_loading && _rows.isNotEmpty && !_exportingCsv,
                buildDocument: _buildDepositRegisterPrintDocument,
                onBusyChanged: (busy) {
                  if (mounted) setState(() => _exportingCsv = busy);
                },
              ),
              IconButton(
                tooltip: TransactionUiText.exportCsv,
                icon: _exportingCsv
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                onPressed: _loading || _rows.isEmpty || _exportingCsv
                    ? null
                    : _exportCsv,
              ),
              IconButton(
                tooltip: TransactionUiText.registerDepositReconcileAction,
                icon: const Icon(Icons.balance_outlined),
                onPressed: _loading ? null : _showReconciliation,
              ),
            ],
          ),
        ),
        Expanded(
          child: SimpleRegisterTabBase(
            loading: _loading,
            error: _error,
            rows: _displayRows,
            headerInfo: TransactionUiText.registerDepositListHeader,
            columnHeaders: const [
              TransactionUiText.registerDepositColDate,
              TransactionUiText.registerDepositColDocNo,
              TransactionUiText.registerDepositColType,
              TransactionUiText.registerDepositColAmount,
              TransactionUiText.registerDepositColParty,
              TransactionUiText.registerDepositColDue,
              TransactionUiText.registerDepositColLedgerDocs,
              TransactionUiText.registerDepositColStatus,
              TransactionUiText.registerDepositColAction,
            ],
            cellBuilder: (r) {
              final status = r['status']?.toString() ?? '-';
              final canSettle = status == 'holding';
              return [
                DataCell(Text(SimpleRegisterTabBase.formatThaiDate(
                    r['docdate']?.toString()))),
                DataCell(Text(r['docno']?.toString() ?? '-')),
                DataCell(Text(_typeLabel(r['deposit_type']?.toString()))),
                DataCell(Text(SimpleRegisterTabBase.formatNumber(r['amount']))),
                DataCell(Text(r['party_name']?.toString() ??
                    r['party_name_snapshot']?.toString() ??
                    '-')),
                DataCell(_dueDateCell(c, r)),
                DataCell(_ledgerDocsCell(r)),
                DataCell(Text(_statusLabel(status))),
                DataCell(canSettle && canSettlePerm
                    ? TextButton(
                        onPressed: () => _openSettlePage(r),
                        child: const Text(
                            TransactionUiText.registerDepositActionSettle),
                      )
                    : const Text('-')),
              ];
            },
            fiscalYear: _fiscalYear,
            onChangeFiscalYear: (v) {
              setState(() => _fiscalYear = v);
              _load();
            },
            onRefresh: _load,
            onRowTap: _openDetailPage,
          ),
        ),
      ]),
      if (canCreate)
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: c.navy,
            foregroundColor: Colors.white,
            onPressed: _openAddPage,
            icon: const Icon(Icons.add),
            label: const Text(TransactionUiText.registerDepositAddFab),
          ),
        ),
    ]);
  }

  String _typeLabel(String? raw) {
    switch (raw) {
      case 'contract_guarantee':
        return TransactionUiText.registerDepositTypeContractGuarantee;
      case 'withholding_tax':
        return TransactionUiText.registerDepositTypeWithholdingTax;
      case 'other':
        return TransactionUiText.registerDepositTypeOther;
      default:
        return '-';
    }
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'holding':
        return TransactionUiText.registerDepositStatusHolding;
      case 'returned':
        return TransactionUiText.registerDepositStatusReturned;
      case 'submitted':
        return TransactionUiText.registerDepositStatusSubmitted;
      case 'forfeited':
        return TransactionUiText.registerDepositStatusForfeited;
      default:
        return raw;
    }
  }
}
