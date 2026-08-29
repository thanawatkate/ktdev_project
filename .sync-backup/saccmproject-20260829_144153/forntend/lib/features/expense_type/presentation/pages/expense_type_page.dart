// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/local_data_source/expense_type_local_data_source.dart';
import 'package:saccm/features/expense_type/presentation/providers/expense_type_provider.dart';
import 'package:saccm/features/expense_type/presentation/utils/expense_type_budget_helpers.dart';
import 'package:saccm/features/expense_type/presentation/widgets/expense_type_editor_sheet.dart';
import 'package:saccm/features/expense_type/presentation/widgets/expense_type_filter_section.dart';
import 'package:saccm/features/expense_type/presentation/widgets/expense_type_item_card.dart';
import 'package:saccm/features/expense_type/presentation/widgets/expense_type_list_empty_state.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseTypePage extends StatelessWidget {
  const ExpenseTypePage({super.key, this.initialExpenseTypeId});

  /// SQLite `expense_type.id` — เปิดชีตแก้ไขทันทีหลังโหลดรายการ
  final String? initialExpenseTypeId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseTypeProvider(),
      child: _ExpenseTypeBody(initialExpenseTypeId: initialExpenseTypeId),
    );
  }
}

class _ExpenseTypeBody extends StatefulWidget {
  const _ExpenseTypeBody({this.initialExpenseTypeId});

  final String? initialExpenseTypeId;

  @override
  State<_ExpenseTypeBody> createState() => _ExpenseTypeBodyState();
}

class _ExpenseTypeBodyState extends State<_ExpenseTypeBody> {
  static const String _fontFamily = 'Kanit';

  String? token;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _codeFocus = FocusNode();
  final FocusNode _remarkFocus = FocusNode();

  List<ExpenseTypeListItem> _items = [];
  bool _isPageLoading = false;
  String? _loadError;
  int _busyDepth = 0;
  String _busyMessage = '';
  String _searchQuery = '';
  String _sortBy = 'sort_asc';
  bool _didHandleInitialExpenseTypeNavigation = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchCtrl.text);
    });
    SchedulerBinding.instance.addPostFrameCallback((_) => _loadPage());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _remarkCtrl.dispose();
    _searchCtrl.dispose();
    _nameFocus.dispose();
    _codeFocus.dispose();
    _remarkFocus.dispose();
    super.dispose();
  }

  Future<T> _runWithBusy<T>({
    required String message,
    required Future<T> Function() action,
  }) async {
    if (mounted) {
      setState(() {
        _busyDepth += 1;
        _busyMessage = message;
      });
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          _busyDepth = _busyDepth > 0 ? _busyDepth - 1 : 0;
        });
      }
    }
  }

  List<ExpenseTypeListItem> get _filteredItems {
    final q = _searchQuery.trim().toLowerCase();
    final result = _items.where((item) {
      if (q.isEmpty) return true;
      return item.name.toLowerCase().contains(q) ||
          item.code.toLowerCase().contains(q) ||
          item.remark.toLowerCase().contains(q);
    }).toList();
    result.sort((a, b) {
      switch (_sortBy) {
        case 'name_asc':
          return a.name.compareTo(b.name);
        case 'sort_asc':
        default:
          final cmp = a.sort.compareTo(b.sort);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
      }
    });
    return result;
  }

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty || _sortBy != 'sort_asc';

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _sortBy = 'sort_asc';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return SafeArea(
      child: AppBusyBackdrop(
        isBusy: _busyDepth > 0,
        message: _busyMessage,
        child: Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            toolbarHeight: 52,
            title: Text(
              TransactionUiText.expenseTypeTitle,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
            backgroundColor: c.cardWhite,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: c.cardBorder),
            ),
          ),
          body: _isPageLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : _loadError != null
                  ? ScrollSafeErrorState(
                      title: TransactionUiText.loadFailedTitle,
                      message: _loadError!,
                      onRetry: _loadPage,
                      retryLabel: TransactionUiText.tryAgain,
                      iconBackgroundColor: c.iconBgExpense,
                      iconColor: c.expenseRed,
                      titleColor: c.textPrimary,
                      messageColor: c.textSecondary,
                      buttonColor: c.navy,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPage,
                      child: Column(
                        children: [
                          ExpenseTypeFilterSection(
                            searchController: _searchCtrl,
                            sortBy: _sortBy,
                            hasActiveFilter: _hasActiveFilter,
                            resultCount: _filteredItems.length,
                            onSortChanged: (v) =>
                                setState(() => _sortBy = v ?? 'sort_asc'),
                            onResetFilters: _resetFilters,
                            footnote:
                                TransactionUiText.expenseTypeSemanticsFootnote,
                          ),
                          Expanded(
                            child: _filteredItems.isEmpty
                                ? ExpenseTypeListEmptyState(
                                    isTotallyEmpty: _items.isEmpty,
                                    hasActiveFilter: _hasActiveFilter,
                                    onClearFilters: _resetFilters,
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 80),
                                    itemCount: _filteredItems.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 6),
                                    itemBuilder: (_, i) => ExpenseTypeItemCard(
                                      item: _filteredItems[i],
                                      onEdit: () => _showSheet(
                                          existing: _filteredItems[i]),
                                      onDelete: () =>
                                          _confirmDelete(_filteredItems[i]),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
          floatingActionButton: SizedBox(
            width: 56,
            height: 56,
            child: FloatingActionButton(
              onPressed: () => _showSheet(),
              backgroundColor: AppColors.of(context).navy,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Data ─────────────────────────────────────────────────────────────────

  Future<void> _loadPage() async {
    await _runWithBusy(
      message: TransactionUiText.expenseTypeListLoadingBusy,
      action: () async {
        if (mounted) {
          setState(() {
            _isPageLoading = true;
            _loadError = null;
          });
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          if (!mounted) return;
          token = prefs.getString('token');
          await _loadItems();
          await _handleInitialExpenseTypeNavigation();
        } catch (_) {
          if (mounted) {
            setState(() => _loadError = TransactionUiText.loadFailedTitle);
          }
        } finally {
          if (mounted) setState(() => _isPageLoading = false);
        }
      },
    );
  }

  Future<void> _handleInitialExpenseTypeNavigation() async {
    if (_didHandleInitialExpenseTypeNavigation) return;
    final targetId = widget.initialExpenseTypeId?.trim() ?? '';
    if (targetId.isEmpty) return;

    ExpenseTypeListItem? target;
    for (final item in _items) {
      if (item.id == targetId) {
        target = item;
        break;
      }
    }
    if (target == null) return;
    _didHandleInitialExpenseTypeNavigation = true;
    if (!mounted) return;
    await _showSheet(existing: target);
  }

  Future<void> _loadItems() async {
    try {
      final ds = ExpenseTypeLocalDataSource();
      final rows = await ds.queryExpenseTypesWithDefaultBudgetJoin();
      if (!mounted) return;
      setState(() {
        _items = rows
            .map((r) => ExpenseTypeListItem(
                  id: r['id']?.toString() ?? '',
                  code: r['code']?.toString() ?? '',
                  name: r['name']?.toString() ?? '',
                  remark: r['remark']?.toString() ?? '',
                  sort: int.tryParse(r['sort']?.toString() ?? '0') ?? 0,
                  use: r['use']?.toString() ?? 'Y',
                  refDefaultBudgetSourceId:
                      r['refDefaultBudgetSource']?.toString().trim() ?? '',
                  defaultBudgetSummary:
                      expenseTypeDefaultBudgetSummaryFromJoinedRow(r),
                ))
            .where((e) => e.id.isNotEmpty)
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = TransactionUiText.loadFailedTitle);
      }
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> _showSheet({ExpenseTypeListItem? existing}) async {
    _nameCtrl.text = existing?.name ?? '';
    _codeCtrl.text = existing?.code ?? '';
    _remarkCtrl.text = existing?.remark ?? '';

    final expenseProvider = context.read<ExpenseTypeProvider>();

    final budgetDs = BudgetSourceLocalDataSource();
    await budgetDs.ensureInitialized();
    final budgetRows = await budgetDs.getAllBudgetSources();
    if (!mounted) return;

    var initialBudgetId = existing?.refDefaultBudgetSourceId.trim() ?? '';
    if (initialBudgetId.isNotEmpty &&
        !budgetRows.any((b) => b.id == initialBudgetId)) {
      initialBudgetId = '';
    }

    String? initialSel = initialBudgetId.isNotEmpty ? initialBudgetId : null;
    if (existing == null && (initialSel == null || initialSel.trim().isEmpty)) {
      initialSel = defaultBudgetSourceIdForExpenseTypeCode(
        _codeCtrl.text,
        budgetRows,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return ChangeNotifierProvider<ExpenseTypeProvider>.value(
          value: expenseProvider,
          child: ExpenseTypeEditorSheet(
            sheetContext: sheetCtx,
            pageContext: context,
            existing: existing,
            budgetRows: budgetRows,
            initialBudgetId: initialSel,
            nameController: _nameCtrl,
            codeController: _codeCtrl,
            remarkController: _remarkCtrl,
            nameFocus: _nameFocus,
            codeFocus: _codeFocus,
            remarkFocus: _remarkFocus,
            onReloadItems: () async {
              if (mounted) await _loadItems();
            },
            onSubmit: (provider, bud) async {
              if (existing == null) {
                return _saveOnPressed(provider, sheetCtx, bud);
              }
              return _updateOnPressed(provider, sheetCtx, existing, bud);
            },
          ),
        );
      },
    );
  }

  Future<bool> _saveOnPressed(
    ExpenseTypeProvider provider,
    BuildContext sheetCtx,
    String refDefaultBudgetSource,
  ) async {
    return _runWithBusy(
      message: 'กำลังบันทึก...',
      action: () async {
        final success = await provider.saveExpenseType(
          token: token ?? '',
          name: _nameCtrl.text,
          code: _codeCtrl.text,
          remark: _remarkCtrl.text,
          sort: 0,
          refDefaultBudgetSource: refDefaultBudgetSource,
        );
        if (!mounted) return false;
        if (success) {
          showAutoDismissAlert(context, TransactionUiText.success,
              TransactionUiText.saveSuccess, 2);
          await _loadItems();
        } else {
          showAutoDismissAlert(context, TransactionUiText.warning,
              provider.error ?? TransactionUiText.saveFailed, null);
        }
        return success;
      },
    );
  }

  Future<bool> _updateOnPressed(
    ExpenseTypeProvider provider,
    BuildContext sheetCtx,
    ExpenseTypeListItem existing,
    String refDefaultBudgetSource,
  ) async {
    return _runWithBusy(
      message: 'กำลังบันทึกการแก้ไข...',
      action: () async {
        final success = await provider.updateExpenseType(
          id: existing.id,
          token: token ?? '',
          name: _nameCtrl.text,
          code: _codeCtrl.text,
          remark: _remarkCtrl.text,
          sort: existing.sort,
          use: existing.use,
          refDefaultBudgetSource: refDefaultBudgetSource,
        );
        if (!mounted) return false;
        if (success) {
          showAutoDismissAlert(context, TransactionUiText.success,
              TransactionUiText.editSuccess, 2);
          await _loadItems();
        } else {
          showAutoDismissAlert(context, TransactionUiText.warning,
              provider.error ?? TransactionUiText.saveFailed, null);
        }
        return success;
      },
    );
  }

  Future<void> _confirmDelete(ExpenseTypeListItem item) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmDialog(
            isDestructive: true,
            title: TransactionUiText.confirmDelete,
            message:
                TransactionUiText.expenseTypeDeleteConfirmQuestion(item.name),
            cancelText: TransactionUiText.cancel,
            confirmText: TransactionUiText.delete,
          ),
        ) ??
        false;
    if (!shouldDelete || !mounted) return;

    await _runWithBusy(
      message: 'กำลังลบ...',
      action: () async {
        final provider = context.read<ExpenseTypeProvider>();
        final success = await provider.deleteExpenseType(
          id: item.id,
          token: token ?? '',
        );
        if (!mounted) return;
        if (success) {
          await _loadItems();
          showAutoDismissAlert(context, TransactionUiText.success,
              TransactionUiText.deleteSuccess, 2);
        } else {
          showAutoDismissAlert(context, TransactionUiText.warning,
              provider.error ?? TransactionUiText.deleteFailed, null);
        }
      },
    );
  }
}
