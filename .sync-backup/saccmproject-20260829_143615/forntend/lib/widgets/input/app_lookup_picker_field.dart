import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

import '../../constants/app_theme.dart';
import 'app_dropdown_field.dart';
import 'app_input.dart';

/// Lookup selector that looks like AppInput, then opens a searchable bottom sheet.
class AppLookupPickerField<T> extends StatefulWidget {
  const AppLookupPickerField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.hintStyle,
    this.helperStyle,
    this.validator,
    this.autovalidateMode,
    this.items = const [],
    this.loadItems,
    this.value,
    this.displayLabel,
    this.onChanged,
    this.enabled = true,
    this.required = false,
    this.clearable = true,
    this.prefixIcon,
    this.pickerTitle,
    this.searchHint,
    this.loadingText,
    this.emptyText,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final String? label;
  final String? hint;
  final String? helperText;
  final TextStyle? hintStyle;
  final TextStyle? helperStyle;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final List<AppDropdownItem<T>> items;
  final Future<List<AppDropdownItem<T>>> Function()? loadItems;
  final T? value;
  final String? displayLabel;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final bool required;
  final bool clearable;
  final Widget? prefixIcon;
  final String? pickerTitle;
  final String? searchHint;
  final String? loadingText;
  final String? emptyText;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  State<AppLookupPickerField<T>> createState() =>
      _AppLookupPickerFieldState<T>();
}

class _AppLookupPickerFieldState<T> extends State<AppLookupPickerField<T>> {
  late final TextEditingController _displayController;

  AppDropdownItem<T>? get _selectedItem {
    final value = widget.value;
    if (value == null) return null;
    for (final item in widget.items) {
      if (item.value == value) return item;
    }
    return null;
  }

  bool get _canSelect => widget.enabled && widget.onChanged != null;
  bool get _canOpen =>
      _canSelect && (widget.items.isNotEmpty || widget.loadItems != null);

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController();
    _syncDisplayText();
  }

  @override
  void didUpdateWidget(covariant AppLookupPickerField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDisplayText();
  }

  @override
  void dispose() {
    _displayController.dispose();
    super.dispose();
  }

  void _syncDisplayText() {
    final label = widget.displayLabel ?? _selectedItem?.label ?? '';
    if (_displayController.text != label) {
      _displayController.text = label;
    }
  }

  Future<void> _openPicker() async {
    if (!_canOpen) return;
    FocusScope.of(context).unfocus();
    final c = AppColors.of(context);
    final selected = await showModalBottomSheet<AppDropdownItem<T>>(
      context: context,
      backgroundColor: c.cardWhite,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (_) => _AppLookupPickerSheet<T>(
        title: widget.pickerTitle ?? widget.label ?? '',
        searchHint:
            widget.searchHint ?? TransactionUiText.lookupPickerSearchHint,
        loadingText:
            widget.loadingText ?? TransactionUiText.lookupPickerLoading,
        emptyText: widget.emptyText ?? TransactionUiText.lookupPickerNoResults,
        emptyActionLabel: widget.emptyActionLabel,
        onEmptyAction: widget.onEmptyAction,
        items: widget.items,
        loadItems: widget.loadItems,
        selectedValue: widget.value,
      ),
    );
    if (selected == null || !mounted) return;
    widget.onChanged?.call(selected.value);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return AppInput(
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      hintStyle: widget.hintStyle,
      helperStyle: widget.helperStyle,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      required: widget.required,
      enabled: widget.enabled,
      readOnly: true,
      controller: _displayController,
      onTap: _canOpen ? _openPicker : null,
      prefixIcon: widget.prefixIcon,
      action: AppInputAction.text(
        suffixIcon: IconButton(
          tooltip: TransactionUiText.lookupPickerOpenTooltip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 22,
            color: widget.enabled ? c.textSecondary : c.textHint,
          ),
          onPressed: _canOpen ? _openPicker : null,
        ),
      ),
    );
  }
}

class _AppLookupPickerSheet<T> extends StatefulWidget {
  const _AppLookupPickerSheet({
    required this.title,
    required this.searchHint,
    required this.loadingText,
    required this.emptyText,
    this.emptyActionLabel,
    this.onEmptyAction,
    required this.items,
    this.loadItems,
    required this.selectedValue,
  });

  final String title;
  final String searchHint;
  final String loadingText;
  final String emptyText;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final List<AppDropdownItem<T>> items;
  final Future<List<AppDropdownItem<T>>> Function()? loadItems;
  final T? selectedValue;

  @override
  State<_AppLookupPickerSheet<T>> createState() =>
      _AppLookupPickerSheetState<T>();
}

class _AppLookupPickerSheetState<T> extends State<_AppLookupPickerSheet<T>> {
  late final TextEditingController _searchController;
  late List<AppDropdownItem<T>> _items;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _items = widget.items;
    _loadItemsIfNeeded();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItemsIfNeeded() async {
    final loader = widget.loadItems;
    if (loader == null) return;
    setState(() => _loading = true);
    final loaded = await loader();
    if (!mounted) return;
    setState(() {
      _items = loaded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((item) {
      if (query.isEmpty) return true;
      return item.label.toLowerCase().contains(query) ||
          (item.subtitle?.toLowerCase().contains(query) ?? false);
    }).toList();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

    return ColoredBox(
      color: c.cardWhite,
      child: SafeArea(
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ColoredBox(
                color: c.cardWhite,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppTheme.sp12,
                          bottom: AppTheme.sp8,
                        ),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.textSecondary.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        widget.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontFamily: 'Kanit',
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: AppInput(
                        controller: _searchController,
                        hint: widget.searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: scheme.primary),
                            const SizedBox(height: AppTheme.sp12),
                            Text(
                              widget.loadingText,
                              style: textTheme.bodyMedium?.copyWith(
                                fontFamily: 'Kanit',
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? _buildEmptyState(context, c, textTheme)
                        : RepaintBoundary(
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.only(bottom: AppTheme.sp12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: c.cardBorder),
                              itemBuilder: (_, index) {
                                final item = filtered[index];
                                final isSelected =
                                    widget.selectedValue != null &&
                                        item.value == widget.selectedValue;
                                return ListTile(
                                  leading: item.leadingIcon,
                                  selected: isSelected,
                                  selectedTileColor:
                                      scheme.primary.withValues(alpha: 0.08),
                                  title: Text(
                                    item.label,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'Kanit',
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  subtitle: item.subtitle == null
                                      ? null
                                      : Text(
                                          item.subtitle!,
                                          style: textTheme.bodySmall?.copyWith(
                                            fontFamily: 'Kanit',
                                            color: c.textSecondary,
                                          ),
                                        ),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          color: scheme.primary,
                                        )
                                      : Icon(
                                          Icons.chevron_right_rounded,
                                          color: c.textSecondary,
                                        ),
                                  onTap: () => Navigator.of(context).pop(item),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppColors c,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.emptyText,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontFamily: 'Kanit',
                color: c.textSecondary,
              ),
            ),
            if (widget.emptyActionLabel != null &&
                widget.onEmptyAction != null) ...[
              const SizedBox(height: AppTheme.sp12),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => widget.onEmptyAction?.call(),
                  );
                },
                child: Text(widget.emptyActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
