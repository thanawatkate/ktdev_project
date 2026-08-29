// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/expense_req_local_data_source.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/features/approval/presentation/pages/approval_page.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/expense_req/presentation/pages/expense_req_add_page.dart';
import 'package:saccm/features/expense_req/presentation/providers/expense_req_provider.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseReqListPage extends StatelessWidget {
  const ExpenseReqListPage({super.key, this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  Widget build(BuildContext context) {
    final existingProvider =
        Provider.of<ExpenseReqProvider?>(context, listen: false);
    final child = _ExpenseReqListView(embeddedInHome: embeddedInHome);
    if (existingProvider != null) return child;

    return ChangeNotifierProvider(
      create: (_) => ExpenseReqProvider(),
      child: child,
    );
  }
}

class _ExpenseReqListView extends StatefulWidget {
  const _ExpenseReqListView({this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  State<_ExpenseReqListView> createState() => _ExpenseReqListPageState();
}

class _ExpenseReqListPageState extends State<_ExpenseReqListView> {
  String? _token;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      if (mounted) context.read<ExpenseReqProvider>().loadList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitDraft(ExpenseReqModel item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final ok = await context.read<ExpenseReqProvider>().submitForApproval(
          localId: item.id,
          token: token,
        );
    if (!mounted) return;
    if (ok) {
      showAutoDismissAlert(
        context,
        TransactionUiText.success,
        TransactionUiText.expenseReqSubmitSuccess,
        2,
      );
      context.read<ExpenseReqProvider>().loadList();
    } else {
      final err = context.read<ExpenseReqProvider>().error;
      if (err != null) {
        showAutoDismissAlert(context, TransactionUiText.error, err, 3);
      }
    }
  }

  Future<void> _deleteDraft(ExpenseReqModel item) async {
    if (item.approvalStatus != 'draft') return;
    final token = _token;
    if (token == null || token.isEmpty) {
      showAutoDismissAlert(
        context,
        TransactionUiText.warning,
        TransactionUiText.noPermissionData,
        3,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmDialog(
            title: TransactionUiText.expenseReqDeleteDraftTitle,
            message: TransactionUiText.expenseReqDeleteDraftMessage(item.docno),
            confirmText: TransactionUiText.delete,
            cancelText: TransactionUiText.cancel,
            isDestructive: true,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final ok = await context.read<ExpenseReqProvider>().deleteDraft(
          localId: item.id,
          token: token,
        );
    if (!mounted) return;
    if (ok) {
      showAutoDismissAlert(
        context,
        TransactionUiText.success,
        TransactionUiText.expenseReqDeleteDraftSuccess,
        2,
      );
    } else {
      final err = context.read<ExpenseReqProvider>().error;
      if (err != null) {
        showAutoDismissAlert(context, TransactionUiText.error, err, 3);
      }
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return TransactionUiText.pendingApproval;
      case 'approved':
        return TransactionUiText.approved;
      case 'rejected':
        return TransactionUiText.rejected;
      default:
        return TransactionUiText.expenseReqStatusDraft;
    }
  }

  Color _statusColor(String s, AppColors c) {
    switch (s) {
      case 'pending':
        return c.loanAmber;
      case 'approved':
        return c.incomeGreen;
      case 'rejected':
        return c.expenseRed;
      default:
        return c.textSecondary;
    }
  }

  Future<void> _openApprovalPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ApprovalPage(),
      ),
    );
    if (mounted) {
      await context.read<ExpenseReqProvider>().loadList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = context.watch<ExpenseReqProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = _filterItems(p.items, query: query);
    final totalAmount = _sumAmount(p.items);
    final pendingCount =
        p.items.where((item) => item.approvalStatus == 'pending').length;

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            _buildHeader(totalAmount, p.items.length, pendingCount, c),
            _buildSearchBar(c),
            Expanded(
              child: p.isLoading && p.items.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: c.expenseRed))
                  : filteredItems.isEmpty
                      ? _buildEmpty(c, hasSearch: query.isNotEmpty)
                      : _buildList(filteredItems, c),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'expense_req_add',
          backgroundColor: c.expenseRed,
          foregroundColor: AppTheme.foregroundFor(c.expenseRed),
          onPressed: () async {
            final changed = await SingleOpenNavigation.push<bool>(
              context,
              key: 'expense_req.form',
              route: MaterialPageRoute<bool>(
                builder: (_) => ExpenseReqAddPage(
                  embeddedInHome: widget.embeddedInHome,
                ),
              ),
            );
            if (changed == true && context.mounted) {
              context.read<ExpenseReqProvider>().loadList();
            }
          },
          icon: const Icon(Icons.note_add_outlined),
          label: const Text(
            TransactionUiText.expenseReqAddTitle,
            style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    double total,
    int count,
    int pendingCount,
    AppColors c,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.cardWhite,
        border: Border(bottom: BorderSide(color: c.cardBorder, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final isWide = constraints.maxWidth >= 640;
          final cardWidth = isWide
              ? (constraints.maxWidth - 20) / 3
              : (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: cardWidth,
                child: _summaryCard(
                  icon: Icons.request_quote_outlined,
                  label: TransactionUiText.summaryTotal,
                  value: NumberFormat('#,##0.00').format(total),
                  unit: TransactionUiText.baht,
                  valueColor: c.expenseRed,
                  bgColor: c.iconBgExpense,
                  c: c,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _summaryCard(
                  icon: Icons.receipt_long_outlined,
                  label: TransactionUiText.itemCount,
                  value: '$count',
                  unit: TransactionUiText.items,
                  valueColor: c.navy,
                  bgColor: c.surface,
                  c: c,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _summaryCard(
                  icon: Icons.pending_actions_outlined,
                  label: TransactionUiText.pendingApproval,
                  value: '$pendingCount',
                  unit: TransactionUiText.items,
                  valueColor: c.loanAmber,
                  bgColor: c.surface,
                  c: c,
                ),
              ),
            ],
          );
        },
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

  Widget _buildSearchBar(AppColors c) {
    final canOpenApproval =
        context.watch<SimpleAuthProvider>().can(PermissionKey.approvalView);
    return Container(
      color: c.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final approvalButton = AppButton.outlined(
            label: TransactionUiText.approvalRecord,
            fullWidth: false,
            onPressed: canOpenApproval ? _openApprovalPage : null,
          );
          final searchInput = AppInput(
            controller: _searchController,
            hint: TransactionUiText.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            onChanged: (_) => setState(() {}),
            action: AppInputAction.text(
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: c.textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
            ),
          );
          if (!canOpenApproval) return searchInput;
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchInput,
                const SizedBox(height: AppTheme.sp8),
                Align(
                  alignment: Alignment.centerRight,
                  child: approvalButton,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: searchInput),
              const SizedBox(width: AppTheme.sp8),
              approvalButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<ExpenseReqModel> items, AppColors c) {
    return RefreshIndicator(
      color: c.expenseRed,
      onRefresh: () => context.read<ExpenseReqProvider>().loadList(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.sp8),
        itemBuilder: (_, i) => _buildCard(items[i], c),
      ),
    );
  }

  Widget _buildCard(ExpenseReqModel item, AppColors c) {
    final amount = double.tryParse(item.amount) ?? 0;
    final status = item.approvalStatus;
    final detail = item.detail?.trim() ?? '';
    final remark = item.remark?.trim() ?? '';
    final rejectReason = item.rejectReason?.trim() ?? '';
    final budgetSourceName = item.budgetSourceName?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.iconBgExpense,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.note_add_outlined,
                    color: c.expenseRed,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.docno,
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(item.docdate ?? item.created),
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 11,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.sp8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusBadge(status, c),
                    ServerSyncStatusBadge(
                      synced: item.synced,
                      syncedColor: c.incomeGreen,
                      pendingColor: c.loanAmber,
                      margin: const EdgeInsets.only(top: AppTheme.sp4),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.memberLabel.isNotEmpty)
                        _infoLine(
                          icon: Icons.person_outline_rounded,
                          text:
                              '${TransactionUiText.requesterPrefix}${item.memberLabel}',
                          c: c,
                        ),
                      if (budgetSourceName.isNotEmpty)
                        _infoLine(
                          icon: Icons.account_balance_wallet_outlined,
                          text:
                              '${TransactionUiText.budgetSourcePrefix}$budgetSourceName',
                          c: c,
                        ),
                      if (detail.isNotEmpty)
                        _infoLine(
                          icon: Icons.subject_rounded,
                          text: detail,
                          c: c,
                        ),
                      if (remark.isNotEmpty)
                        _infoLine(
                          icon: Icons.edit_note_rounded,
                          text: '${TransactionUiText.notePrefix}$remark',
                          c: c,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.sp12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat('#,##0.00').format(amount),
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.expenseRed,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      TransactionUiText.baht,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 10,
                        color: c.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (status == 'rejected' && rejectReason.isNotEmpty) ...[
              const SizedBox(height: AppTheme.sp8),
              _warningLine(
                '${TransactionUiText.reasonPrefix}$rejectReason',
                c,
              ),
            ],
            if (status == 'draft') ...[
              const SizedBox(height: AppTheme.sp12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppButton.danger(
                      label: TransactionUiText.delete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      onPressed: context.watch<ExpenseReqProvider>().isLoading
                          ? null
                          : () => _deleteDraft(item),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sp8),
                  Expanded(
                    flex: 2,
                    child: AppButton.primary(
                      label: TransactionUiText.expenseReqSubmitAction,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      onPressed: context.watch<ExpenseReqProvider>().isLoading
                          ? null
                          : () => _submitDraft(item),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status, AppColors c) {
    final color = _statusColor(status, c);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp8,
        vertical: AppTheme.sp4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontFamily: 'Kanit',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _infoLine({
    required IconData icon,
    required String text,
    required AppColors c,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sp4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 13, color: c.textSecondary),
          ),
          const SizedBox(width: AppTheme.sp4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: c.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningLine(String text, AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp8,
        vertical: AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: c.expenseRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.expenseRed.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Kanit',
          fontSize: 12,
          color: c.expenseRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmpty(AppColors c, {required bool hasSearch}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
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
            const SizedBox(height: AppTheme.sp16),
            Text(
              hasSearch
                  ? TransactionUiText.notFound
                  : TransactionUiText.expenseReqEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Kanit',
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: AppTheme.sp8),
              Text(
                TransactionUiText.tryAnotherKeyword,
                style: TextStyle(
                  fontFamily: 'Kanit',
                  color: c.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<ExpenseReqModel> _filterItems(
    List<ExpenseReqModel> items, {
    required String query,
  }) {
    if (query.isEmpty) return items;
    return items.where((item) {
      final searchable = [
        item.docno,
        item.docdate ?? '',
        item.created,
        item.detail ?? '',
        item.remark ?? '',
        item.memberLabel,
        item.budgetSourceName ?? '',
        _statusLabel(item.approvalStatus),
        item.rejectReason ?? '',
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  double _sumAmount(List<ExpenseReqModel> items) {
    return items.fold(
      0,
      (sum, item) => sum + (double.tryParse(item.amount) ?? 0),
    );
  }

  String _formatDate(String raw) {
    return ThaiDateFormatter.format(raw, fallback: raw);
  }
}
