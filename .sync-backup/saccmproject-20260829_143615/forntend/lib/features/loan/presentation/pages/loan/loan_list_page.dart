import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/core/utils/thai_date_formatter.dart';
import 'package:saccm/features/loan/presentation/pages/loan/loan_add_page.dart';
import 'package:saccm/features/loan/presentation/providers/loan_provider.dart';
import 'package:saccm/widgets/dialog/confirm_dialog.dart';
import 'package:saccm/widgets/sync_status_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoanListPage extends StatelessWidget {
  const LoanListPage({super.key, this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  Widget build(BuildContext context) {
    final existingProvider = Provider.of<LoanProvider?>(context, listen: false);
    final child = _LoanListView(embeddedInHome: embeddedInHome);
    if (existingProvider != null) return child;

    return ChangeNotifierProvider(
      create: (_) => LoanProvider(),
      child: child,
    );
  }
}

class _LoanListView extends StatefulWidget {
  const _LoanListView({this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  State<_LoanListView> createState() => _LoanListPageState();
}

class _LoanListPageState extends State<_LoanListView> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoanProvider>().loadLoanList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = context.watch<LoanProvider>();
    final filtered =
        _filterRows(provider.rows, _searchController.text.toLowerCase());
    final totalAmount = _sumAmount(provider.rows);
    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            _buildHeader(c, totalAmount, provider.rows.length),
            _buildSearchBar(c),
            Expanded(
              child: provider.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary))
                  : filtered.isEmpty
                      ? _buildEmpty(c,
                          hasSearch: _searchController.text.isNotEmpty)
                      : _buildList(c, filtered),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddLoan,
          backgroundColor: c.navy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add, size: 20),
          label: const Text(
            TransactionUiText.addItem,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors c, double total, int count) {
    return Container(
      width: double.infinity,
      color: c.cardWhite,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TransactionUiText.summaryLoan,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  c,
                  icon: Icons.account_balance_wallet_outlined,
                  label: TransactionUiText.summaryTotal,
                  value: NumberFormat('#,##0.00').format(total),
                  unit: TransactionUiText.baht,
                  valueColor: c.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  c,
                  icon: Icons.receipt_outlined,
                  label: TransactionUiText.itemCount,
                  value: '$count',
                  unit: TransactionUiText.items,
                  valueColor: c.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    AppColors c, {
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: valueColor, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '  $unit',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppColors c) {
    return Container(
      color: c.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: TransactionUiText.loanSearchHint,
          hintStyle: TextStyle(color: c.textHint, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: c.textSecondary, size: 18),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 16, color: c.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          filled: true,
          fillColor: c.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: c.cardBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: c.navy, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildList(AppColors c, List<Map<String, dynamic>> rows) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: rows.length,
      itemBuilder: (_, i) => _buildCard(c, rows[i]),
    );
  }

  Widget _buildCard(AppColors c, Map<String, dynamic> row) {
    final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
    final opening =
        double.tryParse(row['opening_outstanding']?.toString() ?? '0') ?? 0;
    final totalPrincipal = amount + opening;
    final borrower = row['borrower']?.toString() ?? '-';
    final remark = row['remark']?.toString() ?? '';
    final created = row['created']?.toString() ?? '';
    final synced = row['synced'] == true;
    final outstanding = (row['outstanding'] as num?)?.toDouble() ??
        double.tryParse(row['outstanding']?.toString() ?? '0') ??
        0;
    final isOverdue = row['is_overdue'] == true;
    final dueDateRaw = row['duedate']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: ListTile(
        onTap: () => _openEditLoan(row),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.iconBgIncome,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.account_balance_wallet_rounded,
              color: c.navy, size: 18),
        ),
        title: Text(
          borrower,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: c.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (remark.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${TransactionUiText.notePrefix}$remark',
                  style: TextStyle(color: c.textHint, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDate(created),
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
                if (dueDateRaw.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${TransactionUiText.loanDuePrefix} ${_formatDate(dueDateRaw)}',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                ],
                ServerSyncStatusBadge(
                  synced: synced,
                  borderRadius: 10,
                  margin: const EdgeInsets.only(left: 8),
                ),
                if (outstanding > 0) ...[
                  const SizedBox(width: 6),
                  _statusBadge(
                    isOverdue
                        ? TransactionUiText.loanOverdueBadge
                        : TransactionUiText.loanOutstandingBadge,
                    isOverdue ? c.expenseRed : c.loanAmber,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 82,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat('#,##0.00').format(totalPrincipal),
                      style: TextStyle(
                        color: c.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (opening > 0)
                      Text(
                        TransactionUiText.loanAmountDocPlusBrought(
                          NumberFormat('#,##0.00').format(amount),
                          NumberFormat('#,##0.00').format(opening),
                        ),
                        style: TextStyle(color: c.textHint, fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(TransactionUiText.baht,
                        style: TextStyle(color: c.textSecondary, fontSize: 10)),
                  ],
                ),
              ),
              IconButton(
                tooltip: TransactionUiText.edit,
                icon: Icon(Icons.edit_rounded,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                onPressed: () => _openEditLoan(row),
              ),
              IconButton(
                tooltip: TransactionUiText.delete,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: c.expenseRed),
                onPressed: () => _confirmDelete(row),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmpty(AppColors c, {bool hasSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch
                ? Icons.search_off
                : Icons.account_balance_wallet_outlined,
            size: 64,
            color: c.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? TransactionUiText.notFound
                : TransactionUiText.emptyLoan,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? TransactionUiText.tryAnotherKeyword
                : TransactionUiText.startByAdding,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddLoan() async {
    final loanProvider = context.read<LoanProvider>();
    final result = await SingleOpenNavigation.push<bool>(
      context,
      key: 'loan.form',
      route: MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: loanProvider,
          child: LoanAddPage(embeddedInHome: widget.embeddedInHome),
        ),
      ),
    );
    if (result == true && mounted) {
      await context.read<LoanProvider>().loadLoanList();
    }
  }

  Future<void> _openEditLoan(Map<String, dynamic> row) async {
    final loanProvider = context.read<LoanProvider>();
    final result = await SingleOpenNavigation.push<bool>(
      context,
      key: 'loan.form',
      route: MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: loanProvider,
          child: LoanAddPage(
            initialData: row,
            embeddedInHome: widget.embeddedInHome,
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      await context.read<LoanProvider>().loadLoanList();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.r16),
        ),
        icon: Icon(Icons.delete_outline_rounded, color: c.expenseRed, size: 30),
        title: TransactionUiText.deleteLoanItem,
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

    final success = await context.read<LoanProvider>().deleteLoan(
          localId: row['id']?.toString() ?? '',
          token: token,
          docno: row['docno']?.toString() ?? '',
        );
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.read<LoanProvider>().error ??
                TransactionUiText.cannotDelete),
          ),
        );
    }
  }

  List<Map<String, dynamic>> _filterRows(
      List<Map<String, dynamic>> rows, String query) {
    if (query.isEmpty) return rows;
    return rows.where((r) {
      final borrower = r['borrower']?.toString().toLowerCase() ?? '';
      final remark = r['remark']?.toString().toLowerCase() ?? '';
      return borrower.contains(query) || remark.contains(query);
    }).toList();
  }

  double _sumAmount(List<Map<String, dynamic>> rows) {
    return rows.fold<double>(0, (sum, r) {
      final a = (r['amount'] as num?)?.toDouble() ??
          double.tryParse(r['amount']?.toString() ?? '0') ??
          0;
      final o = (r['opening_outstanding'] as num?)?.toDouble() ??
          double.tryParse(r['opening_outstanding']?.toString() ?? '0') ??
          0;
      return sum + a + o;
    });
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    return ThaiDateFormatter.format(raw, fallback: raw);
  }
}
