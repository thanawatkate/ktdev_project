import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/features/loan/presentation/pages/repay_loan/repay_loan_add_page.dart';
import 'package:saccm/features/loan/presentation/providers/loan_provider.dart';
import 'package:saccm/features/loan/presentation/providers/repay_loan_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RepayLoanListPage extends StatelessWidget {
  const RepayLoanListPage({super.key, this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  Widget build(BuildContext context) {
    final hasLoanProvider =
        Provider.of<LoanProvider?>(context, listen: false) != null;
    final hasRepayProvider =
        Provider.of<RepayLoanProvider?>(context, listen: false) != null;
    final child = _RepayLoanListView(embeddedInHome: embeddedInHome);

    if (hasLoanProvider && hasRepayProvider) return child;

    return MultiProvider(
      providers: [
        if (!hasLoanProvider)
          ChangeNotifierProvider(create: (_) => LoanProvider()),
        if (!hasRepayProvider)
          ChangeNotifierProvider(create: (_) => RepayLoanProvider()),
      ],
      child: child,
    );
  }
}

class _RepayLoanListView extends StatefulWidget {
  const _RepayLoanListView({this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  State<_RepayLoanListView> createState() => _RepayLoanListPageState();
}

class _RepayLoanListPageState extends State<_RepayLoanListView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LoanProvider>().loadLoanList();
      if (mounted) {
        await context.read<RepayLoanProvider>().loadRepayLoanList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = context.watch<RepayLoanProvider>();
    final loanProvider = context.watch<LoanProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final filteredRows = query.isEmpty
        ? provider.rows
        : provider.rows.where((row) {
            final docno = row['docno']?.toString().toLowerCase() ?? '';
            final refLoan = row['refLoan']?.toString().toLowerCase() ?? '';
            final remark = row['remark']?.toString().toLowerCase() ?? '';
            final amount = row['amount']?.toString().toLowerCase() ?? '';
            return docno.contains(query) ||
                refLoan.contains(query) ||
                remark.contains(query) ||
                amount.contains(query);
          }).toList();
    final total = provider.rows.fold<double>(
      0,
      (sum, r) => sum + (double.tryParse(r['amount']?.toString() ?? '0') ?? 0),
    );
    return Scaffold(
      backgroundColor: c.background,
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.cardWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.cardBorder),
                  ),
                  child: Text(
                    '${TransactionUiText.repayLoanSummaryPrefix} ${NumberFormat('#,##0.00').format(total)} ${TransactionUiText.baht}',
                    style: TextStyle(
                      color: c.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: TransactionUiText.repayLoanSearchHint,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: filteredRows.isEmpty
                      ? Center(
                          child: Text(
                            query.isEmpty
                                ? TransactionUiText.repayLoanEmpty
                                : TransactionUiText.notFound,
                            style: TextStyle(color: c.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemCount: filteredRows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildCard(
                            c,
                            filteredRows[i],
                            loanProvider.rows,
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: c.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(TransactionUiText.addRepayLoan),
      ),
    );
  }

  String _loanDocnoLabel(String refLoan, List<Map<String, dynamic>> loanRows) {
    for (final loan in loanRows) {
      final id = loan['id']?.toString() ?? '';
      final docno = loan['docno']?.toString() ?? '';
      if (id == refLoan || docno == refLoan) {
        return docno.isNotEmpty ? docno : refLoan;
      }
    }
    return refLoan;
  }

  Widget _buildCard(
    AppColors c,
    Map<String, dynamic> row,
    List<Map<String, dynamic>> loanRows,
  ) {
    final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
    final refRaw = row['refLoan']?.toString() ?? '';
    final refLoan = refRaw.isEmpty ? '-' : _loanDocnoLabel(refRaw, loanRows);
    return ListTile(
      tileColor: c.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.cardBorder),
      ),
      title: Text(refLoan,
          style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
      subtitle: Text(
        row['remark']?.toString().isNotEmpty == true
            ? row['remark'].toString()
            : '-',
        style: TextStyle(color: c.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            NumberFormat('#,##0.00').format(amount),
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: Theme.of(context).colorScheme.primary),
            onPressed: () => _openEdit(row),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: c.expenseRed),
            onPressed: () => _delete(row),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdd() async {
    final provider = context.read<RepayLoanProvider>();
    final result = await SingleOpenNavigation.push<bool>(
      context,
      key: 'repay_loan.form',
      route: MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: RepayLoanAddPage(embeddedInHome: widget.embeddedInHome),
        ),
      ),
    );
    if (result == true && mounted) await provider.loadRepayLoanList();
  }

  Future<void> _openEdit(Map<String, dynamic> row) async {
    final provider = context.read<RepayLoanProvider>();
    final result = await SingleOpenNavigation.push<bool>(
      context,
      key: 'repay_loan.form',
      route: MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: RepayLoanAddPage(
            initialData: row,
            embeddedInHome: widget.embeddedInHome,
          ),
        ),
      ),
    );
    if (result == true && mounted) await provider.loadRepayLoanList();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (!mounted) return;
    final ok = await context.read<RepayLoanProvider>().deleteRepayLoan(
          localId: row['id']?.toString() ?? '',
          token: token,
          docno: row['docno']?.toString() ?? '',
        );
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<RepayLoanProvider>().error ??
              TransactionUiText.cannotDelete,
        ),
      ),
    );
  }
}
