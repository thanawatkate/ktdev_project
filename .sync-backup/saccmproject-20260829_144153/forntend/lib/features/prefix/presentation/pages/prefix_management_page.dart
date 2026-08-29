import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/prefix_local_data_source.dart';
import 'package:saccm/widgets/widgets.dart';

class PrefixManagementPage extends StatefulWidget {
  const PrefixManagementPage({super.key});

  @override
  State<PrefixManagementPage> createState() => _PrefixManagementPageState();
}

class _PrefixManagementPageState extends State<PrefixManagementPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;
  static const double _editorSheetMaxWidth = 560;

  final PrefixLocalDataSource _dataSource = PrefixLocalDataSource();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  List<PrefixListItem> _items = [];
  bool _isLoading = true;
  int _busyDepth = 0;
  String _busyMessage = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  List<PrefixListItem> get _filteredItems {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where((item) => item.prefixTh.toLowerCase().contains(q))
        .toList();
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
          if (_busyDepth == 0) _busyMessage = '';
        });
      }
    }
  }

  Future<void> _loadItems() async {
    await _runWithBusy(
      message: TransactionUiText.prefixLoadingBusy,
      action: () async {
        if (mounted) setState(() => _isLoading = true);
        try {
          final items = await _dataSource.getAllPrefixes();
          if (!mounted) return;
          setState(() => _items = items);
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
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
          appBar: _buildAppBar(c),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : _buildContent(c),
          ),
          floatingActionButton: SizedBox(
            width: 56,
            height: 56,
            child: FloatingActionButton(
              onPressed: () => _openEditorSheet(),
              backgroundColor: c.navy,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      title: Text(
        TransactionUiText.prefixManagementTitle,
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
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppTheme.sp12),
          child: IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              size: 20,
              color: c.textSecondary,
            ),
            tooltip: TransactionUiText.prefixManagementTitle,
            visualDensity: VisualDensity.compact,
            onPressed: _showPageGuideDialog,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildContent(AppColors c) {
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding =
              constraints.maxWidth >= 900 ? AppTheme.sp24 : AppTheme.sp16;
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppTheme.sp16,
              horizontalPadding,
              88,
            ),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _maxResponsiveFormWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFilterCard(c),
                      const SizedBox(height: AppTheme.sp12),
                      _buildList(c),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: AppInput(
        controller: _searchController,
        hint: TransactionUiText.prefixSearchHint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildList(AppColors c) {
    final items = _filteredItems;
    if (items.isEmpty) {
      final message = _items.isEmpty
          ? TransactionUiText.prefixEmpty
          : TransactionUiText.prefixNoResult;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.sp32),
        decoration: BoxDecoration(
          color: c.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.r16),
          border: Border.all(color: c.cardBorder, width: 1),
        ),
        child: Column(
          children: [
            Icon(Icons.badge_outlined, size: 42, color: c.textSecondary),
            const SizedBox(height: AppTheme.sp8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _buildPrefixCard(c, items[index]),
          if (index < items.length - 1) const SizedBox(height: AppTheme.sp8),
        ],
      ],
    );
  }

  Widget _buildPrefixCard(AppColors c, PrefixListItem item) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.iconBgIncome,
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.badge_outlined),
        ),
        title: Text(
          item.prefixTh,
          style: TextStyle(
            fontFamily: _fontFamily,
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: item.userCount > 0
            ? Text(
                TransactionUiText.prefixUsageCount(item.userCount),
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: c.textSecondary,
                ),
              )
            : null,
        trailing: Wrap(
          spacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ServerSyncStatusBadge(
              synced: item.synced,
              borderRadius: 10,
              showBorder: false,
            ),
            IconButton(
              tooltip: TransactionUiText.edit,
              onPressed: () => _openEditorSheet(existing: item),
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              tooltip: TransactionUiText.delete,
              onPressed: () => _confirmDelete(item),
              icon: Icon(Icons.delete_outline_rounded, color: c.expenseRed),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditorSheet({PrefixListItem? existing}) async {
    _nameController.text = existing?.prefixTh ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = AppColors.of(sheetContext);
        return AdaptiveContentSheet(
          titleWidget: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _editorSheetMaxWidth),
              child: Text(
                existing == null
                    ? TransactionUiText.prefixAddTitle
                    : TransactionUiText.prefixEditTitle,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppTheme.sp16,
              0,
              AppTheme.sp16,
              MediaQuery.viewInsetsOf(sheetContext).bottom + AppTheme.sp16,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _editorSheetMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppInput(
                      label: TransactionUiText.prefixName,
                      hint: TransactionUiText.prefixNameHint,
                      required: true,
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _savePrefix(sheetContext, existing),
                    ),
                    const SizedBox(height: AppTheme.sp16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton.outlined(
                          label: TransactionUiText.cancel,
                          fullWidth: false,
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                        const SizedBox(width: AppTheme.sp8),
                        AppButton.primary(
                          label: TransactionUiText.save,
                          fullWidth: false,
                          onPressed: () => _savePrefix(sheetContext, existing),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _savePrefix(
    BuildContext sheetContext,
    PrefixListItem? existing,
  ) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack(TransactionUiText.prefixNameRequired);
      return;
    }
    final duplicate =
        await _dataSource.existsByName(name, exceptId: existing?.id);
    if (duplicate) {
      _showSnack(TransactionUiText.prefixDuplicate);
      return;
    }

    await _runWithBusy(
      message: TransactionUiText.prefixSavingBusy,
      action: () async {
        await _dataSource.upsertPrefix(id: existing?.id, prefixTh: name);
        if (!mounted || !sheetContext.mounted) return;
        Navigator.pop(sheetContext);
        await _loadItems();
        if (!mounted) return;
        _showSnack(
          existing == null
              ? TransactionUiText.saveSuccess
              : TransactionUiText.editSuccess,
        );
      },
    );
  }

  Future<void> _confirmDelete(PrefixListItem item) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => ConfirmDialog(
            isDestructive: true,
            title: TransactionUiText.confirmDelete,
            message: TransactionUiText.prefixDeleteConfirmQuestion(
              item.prefixTh,
            ),
            cancelText: TransactionUiText.cancel,
            confirmText: TransactionUiText.delete,
          ),
        ) ??
        false;
    if (!shouldDelete) return;

    await _runWithBusy(
      message: TransactionUiText.prefixDeletingBusy,
      action: () async {
        await _dataSource.deletePrefix(item.id);
        if (!mounted) return;
        await _loadItems();
        _showSnack(TransactionUiText.deleteSuccess);
      },
    );
  }

  Future<void> _showPageGuideDialog() async {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.prefixManagementTitle,
      items: [
        PageGuideItem(
          icon: Icons.badge_outlined,
          text: TransactionUiText.prefixManagementSubtitle,
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
        ),
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.prefixManagementTooltip,
          backgroundColor: c.cardWhite,
        ),
      ],
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: const TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
  }
}
