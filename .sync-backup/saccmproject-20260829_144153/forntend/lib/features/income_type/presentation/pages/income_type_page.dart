// ignore_for_file: use_build_context_synchronously, prefer_interpolation_to_compose_strings

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/lookup_item_local_data_source.dart';
import 'package:saccm/features/income_type/presentation/providers/income_type_provider.dart';
import 'package:saccm/features/income_type/presentation/widgets/income_type_editor_sheet.dart';
import 'package:saccm/features/income_type/presentation/widgets/income_type_filter_section.dart';
import 'package:saccm/features/income_type/presentation/widgets/income_type_item_card.dart';
import 'package:saccm/features/income_type/presentation/widgets/income_type_list_empty_state.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IncomeType extends StatelessWidget {
  const IncomeType({
    super.key,
    this.initialIncomeTypeId,
  });

  final String? initialIncomeTypeId;

  @override
  Widget build(BuildContext context) {
    final existingProvider =
        Provider.of<IncomeTypeProvider?>(context, listen: false);
    final child = _IncomeTypeView(initialIncomeTypeId: initialIncomeTypeId);
    if (existingProvider != null) return child;

    return ChangeNotifierProvider(
      create: (_) => IncomeTypeProvider(
        moneyType: const [],
        sourceGroups: const [],
      ),
      child: child,
    );
  }
}

class _IncomeTypeView extends StatefulWidget {
  const _IncomeTypeView({
    this.initialIncomeTypeId,
  });

  final String? initialIncomeTypeId;

  @override
  State<_IncomeTypeView> createState() => _ComponentsState();
}

class _ComponentsState extends State<_IncomeTypeView> {
  static const String _fontFamily = 'Kanit';

  final IncomeTypeLocalDataSource _localDataSource =
      IncomeTypeLocalDataSource();
  String? token;
  final _name = TextEditingController(), _remark = TextEditingController();
  final _searchController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode(), _remarkFocusNode = FocusNode();
  List<IncomeTypeListItem> _incomeTypes = [];
  List<IncomeTypeListItem> _visibleIncomeTypes = [];
  bool _isPageLoading = false;
  int _busyDepth = 0;
  String _busyMessage = TransactionUiText.incomeTypeListLoadingBusy;
  String? _loadError;
  String _searchQuery = '';
  String _sortBy = 'name_asc';
  Timer? _searchDebounce;
  bool _didHandleInitialIncomeTypeNavigation = false;

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) => loadPage());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _name.dispose();
    _remark.dispose();
    _searchController.dispose();
    _nameFocusNode.dispose();
    _remarkFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
      unawaited(_loadIncomeTypeList());
    });
  }

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty || _sortBy != 'name_asc';

  void _resetFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _sortBy = 'name_asc';
    });
    unawaited(_loadIncomeTypeList());
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
              TransactionUiText.incomeTypeTitle,
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
                      color: Theme.of(context).colorScheme.primary))
              : _loadError != null
                  ? ScrollSafeErrorState(
                      title: TransactionUiText.loadFailedTitle,
                      message: _loadError!,
                      onRetry: loadPage,
                      retryLabel: TransactionUiText.tryAgain,
                      iconBackgroundColor: c.iconBgExpense,
                      iconColor: c.expenseRed,
                      titleColor: c.textPrimary,
                      messageColor: c.textSecondary,
                      buttonColor: c.navy,
                    )
                  : _incomeTypes.isEmpty
                      ? RefreshIndicator(
                          onRefresh: loadPage,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.5,
                                child: IncomeTypeListEmptyState(
                                  isTotallyEmpty: true,
                                  hasActiveFilter: false,
                                  onClearFilters: _resetFilters,
                                  onRetryLoad: loadPage,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: loadPage,
                          child: Column(
                            children: [
                              IncomeTypeFilterSection(
                                searchController: _searchController,
                                sortBy: _sortBy,
                                hasActiveFilter: _hasActiveFilter,
                                resultCount: _visibleIncomeTypes.length,
                                onSortChanged: (v) {
                                  setState(() => _sortBy = v ?? 'name_asc');
                                  unawaited(_loadIncomeTypeList());
                                },
                                onResetFilters: _resetFilters,
                              ),
                              Expanded(
                                child: _visibleIncomeTypes.isEmpty
                                    ? IncomeTypeListEmptyState(
                                        isTotallyEmpty: false,
                                        hasActiveFilter: _hasActiveFilter,
                                        onClearFilters: _resetFilters,
                                        onRetryLoad: loadPage,
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 10, 12, 12),
                                        itemCount: _visibleIncomeTypes.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 6),
                                        itemBuilder: (_, i) =>
                                            IncomeTypeItemCard(
                                          item: _visibleIncomeTypes[i],
                                          onEdit: () =>
                                              _openIncomeTypeEditor(
                                                  existing:
                                                      _visibleIncomeTypes[i]),
                                          onDelete: () =>
                                              _confirmDeleteIncomeType(
                                                  _visibleIncomeTypes[i]),
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
              onPressed: () => _openIncomeTypeEditor(),
              backgroundColor: c.navy,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> loadPage() async {
    await _runWithBusy(
      message: TransactionUiText.incomeTypeListLoadingBusy,
      action: () async {
        if (mounted) {
          setState(() {
            _isPageLoading = true;
            _loadError = null;
          });
        }
        try {
          final prefsData = await SharedPreferences.getInstance();
          if (!mounted) return;
          token = prefsData.getString("token");
          await context.read<IncomeTypeProvider>().loadPage();
          await _loadIncomeTypeList();
          await _handleInitialIncomeTypeNavigation();
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

  Future<void> _handleInitialIncomeTypeNavigation() async {
    if (_didHandleInitialIncomeTypeNavigation) return;
    final targetId = widget.initialIncomeTypeId?.trim() ?? '';
    if (targetId.isEmpty) return;

    IncomeTypeListItem? target;
    for (final item in _incomeTypes) {
      if (item.id == targetId) {
        target = item;
        break;
      }
    }
    if (target == null) return;
    _didHandleInitialIncomeTypeNavigation = true;
    await _openIncomeTypeEditor(existing: target);
  }

  Future<void> _loadIncomeTypeList() async {
    try {
      final rows = await _localDataSource.queryIncomeTypeList(
        searchQuery: _searchQuery,
        sortBy: _sortBy,
      );
      if (!mounted) return;
      setState(() {
        final items = rows
            .map(
              (row) => IncomeTypeListItem(
                id: row['id']?.toString() ?? '',
                code: row['code']?.toString() ?? '',
                name: row['name']?.toString() ?? '',
                detail: row['detail']?.toString() ?? '',
                lastModified: row['lastModified']?.toString() ?? '',
                linkedBudgetSources:
                    int.tryParse(row['linkedCount']?.toString() ?? '0') ?? 0,
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList();
        _incomeTypes = items;
        _visibleIncomeTypes = items;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = TransactionUiText.loadFailedTitle);
      }
    }
  }

  Future<bool> _saveOnPressed() async {
    return _runWithBusy(
      message: TransactionUiText.incomeTypeSavingBusy,
      action: () async {
        FocusScope.of(context).unfocus();
        if (_name.text.trim().isEmpty) {
          showAutoDismissAlert(context, TransactionUiText.warning,
              TransactionUiText.incomeTypeNameRequired, 2);
          return false;
        }
        final provider = context.read<IncomeTypeProvider>();
        if (provider.selectedBudgetSourceIds.isEmpty) {
          showAutoDismissAlert(
            context,
            TransactionUiText.warning,
            TransactionUiText.incomeTypeBudgetSourceRequired,
            2,
          );
          return false;
        }
        final success = await provider.saveIncomeType(
          token: token ?? '',
          name: _name.text,
          remark: _remark.text,
        );
        if (!mounted) return false;
        if (success) {
          showAutoDismissAlert(context, TransactionUiText.success,
              TransactionUiText.saveSuccess, 2);
          _clearInput(context.read<IncomeTypeProvider>());
          await _loadIncomeTypeList();
        } else {
          final err = context.read<IncomeTypeProvider>().error ??
              TransactionUiText.saveFailed;
          showAutoDismissAlert(context, TransactionUiText.warning, err, null);
        }
        return success;
      },
    );
  }

  Future<bool> _updateOnPressed(IncomeTypeListItem existing) async {
    return _runWithBusy(
      message: TransactionUiText.incomeTypeUpdatingBusy,
      action: () async {
        FocusScope.of(context).unfocus();
        if (_name.text.trim().isEmpty) {
          showAutoDismissAlert(
            context,
            TransactionUiText.warning,
            TransactionUiText.incomeTypeNameRequired,
            2,
          );
          return false;
        }
        final provider = context.read<IncomeTypeProvider>();
        if (provider.selectedBudgetSourceIds.isEmpty) {
          showAutoDismissAlert(
            context,
            TransactionUiText.warning,
            TransactionUiText.incomeTypeBudgetSourceRequired,
            2,
          );
          return false;
        }
        final success = await provider.updateIncomeType(
          id: existing.id,
          name: _name.text,
          detail: _remark.text,
          token: token ?? '',
          selectedIds: provider.selectedBudgetSourceIds,
        );
        if (!mounted) return false;
        if (success) {
          showAutoDismissAlert(
            context,
            TransactionUiText.success,
            TransactionUiText.editSuccess,
            2,
          );
          _clearInput(provider);
          await _loadIncomeTypeList();
        } else {
          showAutoDismissAlert(
            context,
            TransactionUiText.warning,
            provider.error ?? TransactionUiText.saveFailed,
            2,
          );
        }
        return success;
      },
    );
  }

  Future<void> _confirmDeleteIncomeType(IncomeTypeListItem item) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmDialog(
            title: TransactionUiText.confirmDelete,
            message:
                TransactionUiText.incomeTypeDeleteConfirmQuestion(item.name),
            cancelText: TransactionUiText.cancel,
            confirmText: TransactionUiText.delete,
          ),
        ) ??
        false;
    if (!shouldDelete || !mounted) return;
    await _deleteIncomeType(item);
  }

  Future<void> _deleteIncomeType(IncomeTypeListItem item) async {
    await _runWithBusy(
      message: TransactionUiText.incomeTypeDeletingBusy,
      action: () async {
        final provider = context.read<IncomeTypeProvider>();
        final success = await provider.deleteIncomeType(
          id: item.id,
          token: token ?? '',
        );
        if (!mounted) return;
        if (success) {
          await _loadIncomeTypeList();
          showAutoDismissAlert(
            context,
            TransactionUiText.success,
            TransactionUiText.deleteSuccess,
            2,
          );
        } else {
          showAutoDismissAlert(
            context,
            TransactionUiText.warning,
            provider.error ?? TransactionUiText.deleteFailed,
            3,
          );
        }
      },
    );
  }

  void _clearInput(IncomeTypeProvider provider) {
    _name.clear();
    _remark.clear();
    provider.clearBudgetSourceSelections();
  }

  Future<void> _openIncomeTypeEditor({IncomeTypeListItem? existing}) async {
    final provider = await _prepareIncomeTypeEditor(existing);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _buildIncomeTypeEditorSheet(
        sheetContext: sheetContext,
        provider: provider,
        existing: existing,
      ),
    );
  }

  Future<IncomeTypeProvider> _prepareIncomeTypeEditor(
    IncomeTypeListItem? existing,
  ) async {
    final provider = context.read<IncomeTypeProvider>();
    _name.text = existing?.name ?? '';
    _remark.text = existing?.detail ?? '';
    await provider.prepareBudgetSourceSelectionsForEditor(existing?.id);
    return provider;
  }

  Widget _buildIncomeTypeEditorSheet({
    required BuildContext sheetContext,
    required IncomeTypeProvider provider,
    required IncomeTypeListItem? existing,
  }) {
    return ChangeNotifierProvider<IncomeTypeProvider>.value(
      value: provider,
      child: SafeArea(
        child: AdaptiveContentSheet(
          title: existing == null
              ? TransactionUiText.incomeTypeManage
              : TransactionUiText.incomeTypeEdit,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.sp16,
              0,
              AppTheme.sp16,
              AppTheme.sp16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: IncomeTypeEditorSheet(
                sheetContext: sheetContext,
                pageContext: context,
                incomeTypeProvider: provider,
                existing: existing,
                nameController: _name,
                remarkController: _remark,
                nameFocusNode: _nameFocusNode,
                remarkFocusNode: _remarkFocusNode,
                onReloadBudgetSources: provider.loadBudgetSources,
                onSubmit: () => _submitIncomeTypeEditor(existing),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _submitIncomeTypeEditor(IncomeTypeListItem? existing) {
    if (existing == null) return _saveOnPressed();
    return _updateOnPressed(existing);
  }
}
