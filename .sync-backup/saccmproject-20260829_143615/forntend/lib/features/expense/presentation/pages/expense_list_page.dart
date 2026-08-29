import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/features/expense/presentation/pages/expense_add_page.dart';
import 'package:saccm/features/expense/presentation/providers/expense_provider.dart';
import 'package:saccm/providers/customTable/custom_table_providers.dart';
import 'package:saccm/providers/customTable/select_table_provider.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseList extends StatelessWidget {
  final double inputWidth;
  final bool embeddedInHome;
  const ExpenseList({
    super.key,
    required this.inputWidth,
    this.embeddedInHome = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasExpenseProvider =
        Provider.of<ExpenseProvider?>(context, listen: false) != null;
    final hasTableProvider =
        Provider.of<CustomTableProvider?>(context, listen: false) != null;
    final hasSelectionProvider =
        Provider.of<SelectionModel?>(context, listen: false) != null;
    final child = _ExpenseListView(
      inputWidth: inputWidth,
      embeddedInHome: embeddedInHome,
    );

    if (hasExpenseProvider && hasTableProvider && hasSelectionProvider) {
      return child;
    }

    return MultiProvider(
      providers: [
        if (!hasExpenseProvider)
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
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

class _ExpenseListView extends StatefulWidget {
  final double inputWidth;
  final bool embeddedInHome;
  const _ExpenseListView({
    required this.inputWidth,
    this.embeddedInHome = false,
  });

  @override
  State<_ExpenseListView> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<_ExpenseListView> {
  late CustomTableProvider customTableProvider;
  late SelectionModel selectionModel;
  final _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      customTableProvider =
          Provider.of<CustomTableProvider>(context, listen: false);
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadData() {
    context
        .read<ExpenseProvider>()
        .loadExpenseList(customTableProvider.addListData);
  }

  @override
  Widget build(BuildContext context) {
    customTableProvider = Provider.of<CustomTableProvider>(context);
    selectionModel = Provider.of<SelectionModel>(context);
    final allRows = customTableProvider.rowData;
    final totalAmount = _sumAmount(allRows);
    final c = AppColors.of(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            _buildHeader(totalAmount, allRows.length, c),
            _buildSearchBar(c),
            Expanded(
              child: context.watch<ExpenseProvider>().isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: c.expenseRed))
                  : context.watch<ExpenseProvider>().error != null
                      ? _buildError(context.watch<ExpenseProvider>().error!, c)
                      : ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (_, value, __) {
                            final filtered = _filterRows(allRows,
                                query: value.text.toLowerCase());
                            return filtered.isEmpty
                                ? _buildEmpty(c,
                                    hasSearch: value.text.isNotEmpty)
                                : _buildList(filtered, c);
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'expense_add_sheet',
          onPressed: () => _openAddExpense(context),
          backgroundColor: c.expenseRed,
          foregroundColor: AppTheme.foregroundFor(c.expenseRed),
          elevation: 3,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            TransactionUiText.addItem,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
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
            icon: Icons.north_rounded,
            label: TransactionUiText.summaryTotal,
            value: NumberFormat('#,##0.00').format(total),
            unit: TransactionUiText.baht,
            valueColor: c.expenseRed,
            bgColor: c.iconBgExpense,
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
  Widget _buildList(List<dynamic> rows, AppColors c) {
    return RefreshIndicator(
      color: c.expenseRed,
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        itemCount: rows.length,
        itemBuilder: (_, i) => _buildCard(rows[i], c),
      ),
    );
  }

  // ─── Card ─────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> row, AppColors c) {
    final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
    final formattedDate = _formatDate(
        row['docdate']?.toString() ?? row['created']?.toString() ?? '');
    final docno = row['docno']?.toString() ?? '-';
    final detail = row['detail']?.toString() ?? '';
    final remark = row['remark']?.toString() ?? '';
    final partyName = row['partyName']?.toString() ?? '';
    final synced = row['synced'] == true;
    final canDelete =
        (row['docStatus']?.toString().toLowerCase() ?? '') != 'posted';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: InkWell(
        onTap: () => _openEditExpense(context, row),
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
                  color: c.expenseRed,
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
                  color: c.iconBgExpense,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.north_rounded, color: c.expenseRed, size: 18),
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
                                size: 11, color: c.expenseRed),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                partyName,
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  color: c.expenseRed,
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
                      color: c.expenseRed,
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
                      onPressed: () => _openEditExpense(context, row),
                    ),
                  ),
                  if (canDelete) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton.outlined(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        iconSize: 15,
                        style: IconButton.styleFrom(
                          side: BorderSide(color: c.cardBorder),
                          foregroundColor: c.expenseRed,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: TransactionUiText.deleteItem,
                        onPressed: () => _confirmDeleteExpense(row),
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

  Future<void> _confirmDeleteExpense(Map<String, dynamic> row) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.r16),
        ),
        icon: Icon(Icons.delete_outline_rounded, color: c.expenseRed, size: 30),
        title: TransactionUiText.deleteItem,
        message:
            '${TransactionUiText.confirmDeleteLoan} ${row['docno'] ?? ''} ${TransactionUiText.confirmDeleteQuestion}',
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.deleteItem,
        confirmColor: c.expenseRed,
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (!mounted) return;
    final success = await context.read<ExpenseProvider>().deleteExpense(
          localId: row['id']?.toString() ?? '',
          token: token,
        );
    if (!mounted) return;
    if (success) {
      _loadData();
      return;
    }
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.read<ExpenseProvider>().error ??
                TransactionUiText.cannotDelete,
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
              color: c.iconBgExpense,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.inbox_outlined,
              size: 36,
              color: c.expenseRed,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? TransactionUiText.notFound
                : TransactionUiText.emptyExpense,
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
    return ScrollSafeErrorState(
      title: TransactionUiText.loadFailedTitle,
      message: message,
      onRetry: _loadData,
      retryLabel: TransactionUiText.tryAgain,
      iconBackgroundColor: c.iconBgExpense,
      iconColor: c.expenseRed,
      titleColor: c.textPrimary,
      messageColor: c.textSecondary,
      buttonColor: c.navy,
      padding: const EdgeInsets.all(24),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  List<dynamic> _filterRows(List<dynamic> rows, {String query = ''}) {
    if (query.isEmpty) return rows;
    return rows.where((r) {
      final docno = r['docno']?.toString().toLowerCase() ?? '';
      final detail = r['detail']?.toString().toLowerCase() ?? '';
      final party = r['partyName']?.toString().toLowerCase() ?? '';
      final remark = r['remark']?.toString().toLowerCase() ?? '';
      return docno.contains(query) ||
          detail.contains(query) ||
          party.contains(query) ||
          remark.contains(query);
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

  Future<void> _openAddExpense(BuildContext context) async {
    final result = await SingleOpenNavigation.push(
      context,
      key: 'expense.form',
      route: MaterialPageRoute(
        builder: (_) => ExpenseAddWidget(
          inputWidth: widget.inputWidth,
          embeddedInHome: widget.embeddedInHome,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) _loadData();
  }

  Future<void> _openEditExpense(
      BuildContext context, Map<String, dynamic> row) async {
    final result = await SingleOpenNavigation.push(
      context,
      key: 'expense.form',
      route: MaterialPageRoute(
        builder: (_) => ExpenseAddWidget(
          inputWidth: widget.inputWidth,
          initialData: row,
          embeddedInHome: widget.embeddedInHome,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) _loadData();
  }
}
