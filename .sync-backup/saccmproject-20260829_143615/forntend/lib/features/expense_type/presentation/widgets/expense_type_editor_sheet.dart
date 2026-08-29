import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';
import 'package:saccm/features/budget_source/presentation/pages/budget_source_page.dart';
import 'package:saccm/features/expense_type/presentation/providers/expense_type_provider.dart';
import 'package:saccm/features/expense_type/presentation/utils/expense_type_budget_helpers.dart';
import 'package:saccm/features/expense_type/presentation/widgets/expense_type_item_card.dart';
import 'package:saccm/widgets/widgets.dart';

class ExpenseTypeEditorSheet extends StatefulWidget {
  const ExpenseTypeEditorSheet({
    super.key,
    required this.sheetContext,
    required this.pageContext,
    required this.existing,
    required this.budgetRows,
    required this.initialBudgetId,
    required this.nameController,
    required this.codeController,
    required this.remarkController,
    required this.nameFocus,
    required this.codeFocus,
    required this.remarkFocus,
    required this.onReloadItems,
    required this.onSubmit,
  });

  final BuildContext sheetContext;
  final BuildContext pageContext;
  final ExpenseTypeListItem? existing;
  final List<BudgetSourceModel> budgetRows;
  final String? initialBudgetId;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController remarkController;
  final FocusNode nameFocus;
  final FocusNode codeFocus;
  final FocusNode remarkFocus;
  final Future<void> Function() onReloadItems;
  final Future<bool> Function(
    ExpenseTypeProvider provider,
    String refDefaultBudgetSource,
  ) onSubmit;

  @override
  State<ExpenseTypeEditorSheet> createState() => _ExpenseTypeEditorSheetState();
}

class _ExpenseTypeEditorSheetState extends State<ExpenseTypeEditorSheet> {
  String? _selectedBudgetId;

  /// When true, [Navigator.pop] is allowed without the outside-tap/back confirm dialog.
  bool _allowPopWithoutConfirm = false;

  Future<void> _confirmBarrierOrBackPop() async {
    if (!mounted) return;
    final navigator = Navigator.of(widget.sheetContext);
    final ok = await showDialog<bool>(
      context: widget.sheetContext,
      builder: (dialogCtx) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.expenseTypeEditorDismissConfirmTitle,
        message: TransactionUiText.expenseTypeEditorDismissConfirmMessage,
        confirmText: TransactionUiText.confirm,
        confirmColor: Theme.of(dialogCtx).colorScheme.primary,
      ),
    );
    if (!mounted || ok != true) return;
    setState(() => _allowPopWithoutConfirm = true);
    navigator.pop();
  }

  void _popSheetWithoutBarrierConfirm() {
    setState(() => _allowPopWithoutConfirm = true);
    Navigator.of(widget.sheetContext).pop();
  }

  @override
  void initState() {
    super.initState();
    _selectedBudgetId = widget.initialBudgetId;
    if (_selectedBudgetId != null &&
        !widget.budgetRows.any((b) => b.id == _selectedBudgetId)) {
      _selectedBudgetId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseTypeProvider>(
      builder: (_, provider, __) {
        final isSaving = provider.isLoading;
        final hasBudgetRows = widget.budgetRows.isNotEmpty;
        final scheme = Theme.of(context).colorScheme;
        final sheetCtx = widget.sheetContext;
        final screenWidth = MediaQuery.of(sheetCtx).size.width;
        final col = screenWidth >= 720 ? 2 : 1;
        final inputWidth = (screenWidth - 24 - ((col - 1) * 8)) / col;
        final existing = widget.existing;

        final canSubmit = widget.nameController.text.trim().isNotEmpty &&
            hasBudgetRows &&
            (_selectedBudgetId?.trim().isNotEmpty ?? false) &&
            !isSaving;

        return PopScope(
          canPop: !isSaving && _allowPopWithoutConfirm,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || isSaving) return;
            _confirmBarrierOrBackPop();
          },
          child: SafeArea(
            child: AdaptiveContentSheet(
              title: existing == null
                  ? TransactionUiText.expenseTypeManage
                  : TransactionUiText.expenseTypeEdit,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSaving) ...[
                        const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 8),
                      ],
                      if (!hasBudgetRows) ...[
                        Text(
                          TransactionUiText.expenseTypeNoBudgetSourcesHint,
                          style: Theme.of(sheetCtx)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.error),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  _popSheetWithoutBarrierConfirm();
                                  await Navigator.of(widget.pageContext)
                                      .push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const BudgetSourcePage(),
                                    ),
                                  );
                                  await widget.onReloadItems();
                                },
                          icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18),
                          label: const Text(
                            TransactionUiText.expenseTypeOpenBudgetSourcePage,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      IgnorePointer(
                        ignoring: isSaving,
                        child: Opacity(
                          opacity: isSaving ? 0.7 : 1,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: inputWidth,
                                child: AppInput(
                                  label: TransactionUiText.expenseTypeName,
                                  required: true,
                                  focusNode: widget.nameFocus,
                                  controller: widget.nameController,
                                  onChanged: (_) => setState(() {}),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? TransactionUiText
                                              .expenseTypeNameRequired
                                          : null,
                                ),
                              ),
                              SizedBox(
                                width: inputWidth,
                                child: AppInput(
                                  label: TransactionUiText.expenseTypeCode,
                                  hint: 'เช่น 01, 02',
                                  focusNode: widget.codeFocus,
                                  controller: widget.codeController,
                                  onChanged: existing == null
                                      ? (_) => setState(() {
                                            _selectedBudgetId =
                                                defaultBudgetSourceIdForExpenseTypeCode(
                                              widget.codeController.text,
                                              widget.budgetRows,
                                            );
                                          })
                                      : null,
                                ),
                              ),
                              SizedBox(
                                width: inputWidth,
                                child: AppInput(
                                  label: TransactionUiText.remark,
                                  hint: 'คำอธิบายประเภทนี้ (ไม่บังคับ)',
                                  focusNode: widget.remarkFocus,
                                  controller: widget.remarkController,
                                  maxLines: 2,
                                  minLines: 2,
                                ),
                              ),
                              if (hasBudgetRows)
                                SizedBox(
                                  width: inputWidth,
                                  child: AppLookupPickerField<String>(
                                    label: TransactionUiText.budgetSourceTitle,
                                    required: true,
                                    items: widget.budgetRows
                                        .map(
                                          (b) => AppDropdownItem<String>(
                                            value: b.id,
                                            label:
                                                expenseTypeBudgetDropdownLabel(
                                                    b),
                                          ),
                                        )
                                        .toList(),
                                    value: _selectedBudgetId != null &&
                                            widget.budgetRows.any(
                                              (b) => b.id == _selectedBudgetId,
                                            )
                                        ? _selectedBudgetId
                                        : null,
                                    clearable: false,
                                    hint: TransactionUiText
                                        .expenseTypeDefaultBudgetRequired,
                                    hintStyle: (_selectedBudgetId == null ||
                                            _selectedBudgetId!.trim().isEmpty)
                                        ? TextStyle(
                                            color: scheme.error,
                                            fontFamily: 'Kanit',
                                            fontWeight: FontWeight.w600,
                                          )
                                        : null,
                                    onChanged: (v) => setState(() {
                                      _selectedBudgetId = v;
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppButton.primary(
                        label: existing == null
                            ? TransactionUiText.save
                            : TransactionUiText.saveEdit,
                        icon: const Icon(Icons.save_rounded, size: 18),
                        isLoading: isSaving,
                        onPressed: canSubmit
                            ? () async {
                                final bud = _selectedBudgetId?.trim() ?? '';
                                if (bud.isEmpty) return;
                                final success =
                                    await widget.onSubmit(provider, bud);
                                if (success && sheetCtx.mounted) {
                                  _popSheetWithoutBarrierConfirm();
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
