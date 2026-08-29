import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/income/presentation/pages/income_add_page.dart';
import 'package:saccm/features/income/presentation/providers/income_provider.dart';
import 'package:saccm/providers/customTable/custom_table_providers.dart';
import 'package:saccm/providers/customTable/select_table_provider.dart';
import 'package:saccm/widgets/widgets.dart';

class IncomeList extends StatelessWidget {
  final double inputWidth;
  final bool embeddedInHome;
  const IncomeList({
    super.key,
    required this.inputWidth,
    this.embeddedInHome = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasIncomeProvider =
        Provider.of<IncomeProvider?>(context, listen: false) != null;
    final hasTableProvider =
        Provider.of<CustomTableProvider?>(context, listen: false) != null;
    final hasSelectionProvider =
        Provider.of<SelectionModel?>(context, listen: false) != null;
    final child = _IncomeListView(
      inputWidth: inputWidth,
      embeddedInHome: embeddedInHome,
    );

    if (hasIncomeProvider && hasTableProvider && hasSelectionProvider) {
      return child;
    }

    return MultiProvider(
      providers: [
        if (!hasIncomeProvider)
          ChangeNotifierProvider(
            create: (_) => IncomeProvider(monneyType: [], incomeType: []),
          ),
        if (!hasTableProvider)
          ChangeNotifierProvider(
            create: (_) => CustomTableProvider(rowData: []),
          ),
        if (!hasSelectionProvider)
          ChangeNotifierProvider(
            create: (_) => SelectionModel(0, []),
          ),
      ],
      child: child,
    );
  }
}

class _IncomeListView extends StatefulWidget {
  final double inputWidth;
  final bool embeddedInHome;
  const _IncomeListView({
    required this.inputWidth,
    this.embeddedInHome = false,
  });

  @override
  State<_IncomeListView> createState() => _IncomeListState();
}

class _IncomeListState extends State<_IncomeListView> {
  late CustomTableProvider customTableProvider;
  late SelectionModel selectionModel;
  final _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      customTableProvider =
          Provider.of<CustomTableProvider>(context, listen: false);
      _loadSession();
      _loadData();
    });
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _token = prefs.getString('token') ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadData() {
    context
        .read<IncomeProvider>()
        .loadIncomeList(customTableProvider.addListData);
  }

  @override
  Widget build(BuildContext context) {
    customTableProvider = Provider.of<CustomTableProvider>(context);
    selectionModel = Provider.of<SelectionModel>(context);
    final allRows = customTableProvider.rowData;
    final totalAmount = _sumAmount(allRows);
    final c = AppColors.of(context);
    final canDeleteIncome =
        context.read<SimpleAuthProvider>().can(PermissionKey.incomeDelete);

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            _buildHeader(totalAmount, allRows.length, c),
            _buildSearchBar(c),
            Expanded(
              child: context.watch<IncomeProvider>().isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: c.incomeGreen))
                  : context.watch<IncomeProvider>().error != null
                      ? _buildError(context.watch<IncomeProvider>().error!, c)
                      : ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (_, value, __) {
                            final filtered = _filterRows(allRows,
                                query: value.text.toLowerCase());
                            return filtered.isEmpty
                                ? _buildEmpty(c,
                                    hasSearch: value.text.isNotEmpty)
                                : _buildList(filtered, c,
                                    canDeleteIncome: canDeleteIncome);
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddIncome(context),
          backgroundColor: c.incomeGreen,
          foregroundColor: AppTheme.foregroundFor(c.incomeGreen),
          elevation: 3,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            TransactionUiText.addItem,
            style: TextStyle(
                fontFamily: 'Kanit', fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────
  Widget _buildHeader(double total, int count, AppColors c) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.cardWhite,
        border: Border(bottom: BorderSide(color: c.cardBorder, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
              child: _summaryCard(
            icon: Icons.south_rounded,
            label: TransactionUiText.summaryTotal,
            value: NumberFormat('#,##0.00').format(total),
            unit: TransactionUiText.baht,
            valueColor: c.incomeGreen,
            bgColor: c.iconBgIncome,
            c: c,
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _summaryCard(
            icon: Icons.receipt_long_outlined,
            label: TransactionUiText.itemCount,
            value: '$count',
            unit: TransactionUiText.items,
            valueColor: c.navy,
            bgColor: c.surface,
            c: c,
          )),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color valueColor,
    required Color bgColor,
    required AppColors c,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: valueColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    fontFamily: 'Kanit',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: TextStyle(
                            color: valueColor,
                            fontSize: 16,
                            fontFamily: 'Kanit',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '  $unit',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11,
                            fontFamily: 'Kanit',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────
  Widget _buildSearchBar(AppColors c) {
    return Container(
      color: c.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (_, value, __) => AppInput(
          label: TransactionUiText.search,
          hint: TransactionUiText.searchHint,
          controller: _searchController,
          focusNode: _searchFocusNode,
          prefixIcon: const Icon(Icons.search_rounded),
          textInputAction: TextInputAction.search,
          action: AppInputAction.text(
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: c.textSecondary,
                    ),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // ─── List ─────────────────────────────────────────────────────────
  Widget _buildList(
    List<dynamic> rows,
    AppColors c, {
    required bool canDeleteIncome,
  }) {
    return RefreshIndicator(
      color: c.incomeGreen,
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        itemCount: rows.length,
        itemBuilder: (_, i) =>
            _buildCard(rows[i], c, canDeleteIncome: canDeleteIncome),
      ),
    );
  }

  // ─── Card ─────────────────────────────────────────────────────────
  Widget _buildCard(
    Map<String, dynamic> row,
    AppColors c, {
    required bool canDeleteIncome,
  }) {
    final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
    final formattedDate = _formatDate(
        row['docdate']?.toString() ?? row['created']?.toString() ?? '');
    final docno = row['docno']?.toString() ?? '-';
    final detail = row['detail']?.toString() ?? '';
    final remark = row['remark']?.toString() ?? '';
    final bankReference = row['bankReference']?.toString() ??
        row['bank_reference']?.toString() ??
        '';
    final partyName = row['partyName']?.toString() ?? '';
    final budgetSourceName = row['budgetSourceName']?.toString() ?? '';
    final synced = row['synced'] == true;
    final docStatusRaw = _incomeListDocStatusRaw(row);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: InkWell(
        onTap: () => _openEditIncome(context, row),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
          child: Row(
            children: [
              // ── Left accent bar ──
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: _incomeListDocStatusAccentBar(c, docStatusRaw),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Icon ──
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.iconBgIncome,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.south_rounded, color: c.incomeGreen, size: 18),
              ),
              const SizedBox(width: 10),
              // ── Content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              docno,
                              style: TextStyle(
                                fontFamily: 'Kanit',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          _incomeDocStatusBadge(docStatusRaw, c),
                          ServerSyncStatusBadge(
                            synced: synced,
                            syncedColor: c.incomeGreen,
                            pendingColor: c.loanAmber,
                            margin: const EdgeInsets.only(left: 4),
                          ),
                        ],
                      ),
                      if (partyName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 11, color: c.incomeGreen),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                partyName,
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  color: c.incomeGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: TextStyle(
                              fontFamily: 'Kanit',
                              color: c.textSecondary,
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (budgetSourceName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.account_balance_outlined,
                                size: 11,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                budgetSourceName,
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  color: c.navy,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (bankReference.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 11, color: c.textSecondary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                bankReference,
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  color: c.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 11, color: c.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            formattedDate,
                            style: TextStyle(
                                fontFamily: 'Kanit',
                                color: c.textSecondary,
                                fontSize: 11),
                          ),
                          if (remark.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.edit_note_rounded,
                                size: 11, color: c.textSecondary),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                remark,
                                style: TextStyle(
                                    fontFamily: 'Kanit',
                                    color: c.textSecondary,
                                    fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ── Amount + edit ──
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat('#,##0.00').format(amount),
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      color: c.incomeGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    TransactionUiText.baht,
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      color: c.textSecondary,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton.outlined(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      iconSize: 15,
                      style: IconButton.styleFrom(
                        side: BorderSide(color: c.cardBorder),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: TransactionUiText.edit,
                      onPressed: () => _openEditIncome(context, row),
                    ),
                  ),
                  if (canDeleteIncome) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton.outlined(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        iconSize: 15,
                        style: IconButton.styleFrom(
                          side: BorderSide(color: c.cardBorder),
                          foregroundColor: c.expenseRed,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: TransactionUiText.delete,
                        onPressed: () => _confirmDeleteIncome(row),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty ────────────────────────────────────────────────────────
  Widget _buildEmpty(AppColors c, {bool hasSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.iconBgIncome,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.inbox_outlined,
              size: 36,
              color: c.incomeGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? TransactionUiText.notFound
                : TransactionUiText.emptyIncome,
            style: TextStyle(
              fontFamily: 'Kanit',
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? TransactionUiText.tryAnotherKeyword
                : TransactionUiText.startByAdding,
            style: TextStyle(
              fontFamily: 'Kanit',
              color: c.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error ────────────────────────────────────────────────────────
  Widget _buildError(String message, AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.iconBgExpense,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded,
                  color: c.expenseRed, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              TransactionUiText.loadFailedTitle,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Kanit', color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadData,
              style: FilledButton.styleFrom(backgroundColor: c.navy),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                TransactionUiText.tryAgain,
                style:
                    TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  String _incomeListDocStatusRaw(Map<String, dynamic> r) {
    final s = (r['docStatus'] ?? r['doc_status'] ?? 'posted')
        .toString()
        .trim()
        .toLowerCase();
    if (s == 'draft' || s == 'approved' || s == 'posted') return s;
    return 'posted';
  }

  String _incomeListDocStatusLabel(String raw) {
    switch (raw) {
      case 'draft':
        return TransactionUiText.incomeDocStatusDraft;
      case 'approved':
        return TransactionUiText.incomeDocStatusApproved;
      case 'posted':
      default:
        return TransactionUiText.incomeDocStatusPosted;
    }
  }

  Color _incomeListDocStatusColor(AppColors c, String raw) {
    switch (raw) {
      case 'draft':
        return c.textSecondary;
      case 'approved':
        return Colors.orange.shade700;
      case 'posted':
      default:
        return c.incomeGreen;
    }
  }

  Color _incomeListDocStatusAccentBar(AppColors c, String raw) =>
      _incomeListDocStatusColor(c, raw);

  Widget _incomeDocStatusBadge(String raw, AppColors c) {
    final color = _incomeListDocStatusColor(c, raw);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          _incomeListDocStatusLabel(raw),
          style: TextStyle(
            fontFamily: 'Kanit',
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<dynamic> _filterRows(List<dynamic> rows, {String query = ''}) {
    if (query.isEmpty) return rows;
    return rows.where((r) {
      final docno = r['docno']?.toString().toLowerCase() ?? '';
      final detail = r['detail']?.toString().toLowerCase() ?? '';
      final bankReference = (r['bankReference'] ?? r['bank_reference'])
              ?.toString()
              .toLowerCase() ??
          '';
      final party = r['partyName']?.toString().toLowerCase() ?? '';
      final budgetSource =
          r['budgetSourceName']?.toString().toLowerCase() ?? '';
      final st = _incomeListDocStatusRaw(r as Map<String, dynamic>);
      final stLabel = _incomeListDocStatusLabel(st).toLowerCase();
      return docno.contains(query) ||
          detail.contains(query) ||
          bankReference.contains(query) ||
          party.contains(query) ||
          budgetSource.contains(query) ||
          st.contains(query) ||
          stLabel.contains(query);
    }).toList();
  }

  double _sumAmount(List<dynamic> rows) => rows.fold(
        0.0,
        (sum, r) =>
            sum + (double.tryParse(r['amount']?.toString() ?? '0') ?? 0),
      );

  String _formatDate(String raw) {
    return ThaiDateFormatter.format(raw, fallback: raw);
  }

  Future<void> _openAddIncome(BuildContext context) async {
    final result = await SingleOpenNavigation.push(
      context,
      key: 'income.form',
      route: MaterialPageRoute(
        builder: (_) => incomeAddWidget(
          inputWidth: widget.inputWidth,
          embeddedInHome: widget.embeddedInHome,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _openEditIncome(
      BuildContext context, Map<String, dynamic> row) async {
    final result = await SingleOpenNavigation.push(
      context,
      key: 'income.form',
      route: MaterialPageRoute(
        builder: (_) => incomeAddWidget(
          inputWidth: widget.inputWidth,
          initialData: row,
          embeddedInHome: widget.embeddedInHome,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _confirmDeleteIncome(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final docno = row['docno']?.toString() ?? '-';
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmDialog(
            title: TransactionUiText.confirmDelete,
            message: 'ต้องการลบรายการรับเงินเลขที่ "$docno" หรือไม่?',
            cancelText: TransactionUiText.cancel,
            confirmText: TransactionUiText.delete,
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    final tokenToUse = _token.isNotEmpty
        ? _token
        : (await SharedPreferences.getInstance()).getString('token') ?? '';
    if (!mounted) return;
    final success = await context.read<IncomeProvider>().deleteIncome(
          localId: id,
          token: tokenToUse,
        );
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.deleteSuccess)),
      );
      _loadData();
      return;
    }
    final err =
        context.read<IncomeProvider>().error ?? TransactionUiText.deleteFailed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err)),
    );
  }
}

// ignore: camel_case_types
class incomeAddWidget extends StatelessWidget {
  const incomeAddWidget({
    super.key,
    required this.inputWidth,
    this.initialData,
    this.embeddedInHome = false,
  });
  final double inputWidth;
  final Map<String, dynamic>? initialData;
  final bool embeddedInHome;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => IncomeProvider(monneyType: [], incomeType: [])),
      ],
      child: IncomeAddData(
        inputWidth: inputWidth,
        initialData: initialData,
        embeddedInHome: embeddedInHome,
      ),
    );
  }
}
