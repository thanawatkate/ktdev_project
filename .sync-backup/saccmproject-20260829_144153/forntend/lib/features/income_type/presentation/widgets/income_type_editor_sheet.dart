import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/budget_source/presentation/pages/budget_source_page.dart';
import 'package:saccm/features/income_type/presentation/providers/income_type_provider.dart';
import 'package:saccm/features/income_type/presentation/widgets/income_type_item_card.dart';
import 'package:saccm/widgets/dialog/form_leave_confirm_dialog.dart';
import 'package:saccm/widgets/widgets.dart';

class IncomeTypeEditorSheet extends StatefulWidget {
  const IncomeTypeEditorSheet({
    super.key,
    required this.sheetContext,
    required this.pageContext,
    required this.incomeTypeProvider,
    required this.existing,
    required this.nameController,
    required this.remarkController,
    required this.nameFocusNode,
    required this.remarkFocusNode,
    required this.onSubmit,
    required this.onReloadBudgetSources,
  });

  final BuildContext sheetContext;
  final BuildContext pageContext;
  final IncomeTypeProvider incomeTypeProvider;
  final IncomeTypeListItem? existing;
  final TextEditingController nameController;
  final TextEditingController remarkController;
  final FocusNode nameFocusNode;
  final FocusNode remarkFocusNode;
  final Future<bool> Function() onSubmit;
  final Future<void> Function() onReloadBudgetSources;

  @override
  State<IncomeTypeEditorSheet> createState() => _IncomeTypeEditorSheetState();
}

class _IncomeTypeEditorSheetState extends State<IncomeTypeEditorSheet> {
  /// When true, [Navigator.pop] is allowed without the outside-tap/back confirm dialog.
  bool _allowPopWithoutConfirm = false;
  late final String _initialName;
  late final String _initialRemark;
  late final Set<String> _initialBudgetSourceIds;

  @override
  void initState() {
    super.initState();
    _initialName = widget.nameController.text.trim();
    _initialRemark = widget.remarkController.text.trim();
    _initialBudgetSourceIds =
        Set<String>.from(widget.incomeTypeProvider.selectedBudgetSourceIds);
  }

  Future<void> _confirmBarrierOrBackPop() async {
    if (!mounted) return;
    if (!_shouldConfirmBeforeLeave()) {
      _popSheetWithoutBarrierConfirm();
      return;
    }
    final ok = await showFormLeaveConfirmDialog(
      widget.sheetContext,
      title: TransactionUiText.incomeTypeEditorDismissConfirmTitle,
      message: TransactionUiText.incomeTypeEditorDismissConfirmMessage,
    );
    if (!mounted || ok != true) return;
    _popSheetWithoutBarrierConfirm();
  }

  void _popSheetWithoutBarrierConfirm() {
    if (!mounted) return;
    setState(() => _allowPopWithoutConfirm = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sheetContext.mounted) {
        Navigator.of(widget.sheetContext).pop();
      }
    });
  }

  bool _shouldConfirmBeforeLeave() {
    final currentName = widget.nameController.text.trim();
    final currentRemark = widget.remarkController.text.trim();
    final currentBudgetSourceIds =
        widget.incomeTypeProvider.selectedBudgetSourceIds;

    if (widget.existing == null) {
      return currentName.isNotEmpty ||
          currentRemark.isNotEmpty ||
          currentBudgetSourceIds.isNotEmpty;
    }

    return currentName != _initialName ||
        currentRemark != _initialRemark ||
        !_setEquals(currentBudgetSourceIds, _initialBudgetSourceIds);
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtx = widget.sheetContext;
    final width = MediaQuery.of(sheetCtx).size.width;
    final col = width >= 720 ? 2 : 1;
    final inputWidth = (width - 24 - ((col - 1) * 8)) / col;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.nameController,
        widget.remarkController,
        widget.incomeTypeProvider,
      ]),
      builder: (context, _) {
        final provider = widget.incomeTypeProvider;
        final isSaving = provider.isLoading;
        final hasLinkedBudgetSources =
            provider.selectedBudgetSourceIds.isNotEmpty;
        final canSubmit = widget.nameController.text.trim().isNotEmpty &&
            hasLinkedBudgetSources &&
            !isSaving;
        final existing = widget.existing;

        return PopScope(
          canPop: !isSaving && _allowPopWithoutConfirm,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || isSaving) return;
            _confirmBarrierOrBackPop();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSaving) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 8),
              ],
              IgnorePointer(
                ignoring: isSaving,
                child: Opacity(
                  opacity: isSaving ? 0.7 : 1,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      SizedBox(
                        width: inputWidth,
                        child: AppInput(
                          label: TransactionUiText.incomeTypeName,
                          required: true,
                          focusNode: widget.nameFocusNode,
                          controller: widget.nameController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (p0) {
                            if (p0 == null || p0.isEmpty) {
                              return TransactionUiText.nameRequired;
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: inputWidth,
                        child: AppInput(
                          label: TransactionUiText.remark,
                          focusNode: widget.remarkFocusNode,
                          controller: widget.remarkController,
                        ),
                      ),
                      SizedBox(
                        width: inputWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppDropdownField<String>(
                              label: TransactionUiText
                                  .incomeTypeBudgetLinkFieldLabel,
                              hint: provider.budgetSources.isEmpty
                                  ? TransactionUiText
                                      .incomeTypeBudgetSourcesEmptyHint
                                  : TransactionUiText.incomeTypeBudgetLinkHint,
                              helperText: provider.budgetSources.isEmpty
                                  ? TransactionUiText
                                      .incomeTypeBudgetSourcesEmptyHelper
                                  : TransactionUiText
                                      .incomeTypeBudgetLinkManualHelper,
                              enabled: provider.budgetSources.isNotEmpty,
                              isMultiSelect: true,
                              multiSelectTitle: TransactionUiText
                                  .incomeTypeSelectBudgetSourcesTitle,
                              items: provider.budgetSources
                                  .map(
                                    (item) => AppDropdownItem<String>(
                                      value: item[0],
                                      label: item[1],
                                    ),
                                  )
                                  .toList(),
                              selectedValues: provider.selectedBudgetSourceIds,
                              onMultiChanged: (values) =>
                                  provider.applyBudgetSourceSelections(values),
                            ),
                            if (provider.budgetSources.isEmpty) ...[
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        await Navigator.of(widget.pageContext)
                                            .push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const BudgetSourcePage(),
                                          ),
                                        );
                                        await widget.onReloadBudgetSources();
                                      },
                                icon: const Icon(Icons.arrow_forward_rounded,
                                    size: 16),
                                label: const Text(TransactionUiText
                                    .incomeTypeGoAddBudgetSource),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppButton.primary(
                label: existing == null
                    ? TransactionUiText.save
                    : TransactionUiText.saveEdit,
                icon: const Icon(Icons.save_rounded, size: 18),
                isLoading: provider.isLoading,
                onPressed: canSubmit
                    ? () async {
                        final success = await widget.onSubmit();
                        if (success && sheetCtx.mounted) {
                          _popSheetWithoutBarrierConfirm();
                        }
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
