import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/bank_account_local_data_source.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';

class BudgetSourceFormResult {
  final String code;
  final String name;
  final String fiscalYear;
  final String budgetType;
  final String? refMoneyGroup;
  final String? description;
  final String? refBankAccount;

  const BudgetSourceFormResult({
    required this.code,
    required this.name,
    required this.fiscalYear,
    required this.budgetType,
    this.refMoneyGroup,
    this.description,
    this.refBankAccount,
  });
}

Future<BudgetSourceFormResult?> showBudgetSourceFormDialog({
  required BuildContext context,
  required List<String> budgetTypes,
  required List<MoneyGroupOption> moneyGroups,
  required List<LocalBankAccountItem> bankAccounts,
  required bool Function(String code) isCodeFormatValid,
  required bool Function(String code) isCodeDuplicate,
  required String Function(String budgetType, String fiscalYear) generateCode,
  BudgetSourceModel? existing,
}) async {
  final codeCtrl = TextEditingController(text: existing?.code);
  final nameCtrl = TextEditingController(text: existing?.name);
  final yearCtrl = TextEditingController(
    text: existing?.fiscalYear ?? FiscalYear.currentBuddhist().toString(),
  );
  final descCtrl = TextEditingController(text: existing?.description);
  String selectedType = existing?.budgetType ?? TransactionUiText.budgetTypeGov;
  String? selectedMoneyGroup = existing?.refMoneyGroup;
  String? selectedBankAccount = existing?.refBankAccount;
  // ถ้า id เดิมไม่มีในรายการ (เช่น ถูกลบ) → ปล่อยให้ dropdown ว่าง
  if (selectedMoneyGroup != null &&
      !moneyGroups.any((g) => g.id == selectedMoneyGroup)) {
    selectedMoneyGroup = null;
  }
  if (selectedBankAccount != null &&
      !bankAccounts.any((b) => b.id == selectedBankAccount)) {
    selectedBankAccount = null;
  }

  final result = await showModalBottomSheet<BudgetSourceFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) {
      final formKey = GlobalKey<FormState>();
      return StatefulBuilder(builder: (ctx, setStateDialog) {
        return SafeArea(
          child: AdaptiveContentSheet(
            title: existing == null
                ? TransactionUiText.addBudgetSource
                : TransactionUiText.editBudgetSource,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                AppTheme.sp16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: TransactionUiText.budgetSourceCodeRequired,
                          helperText: TransactionUiText.budgetCodeFormatHint,
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim().toUpperCase();
                          if (value.isEmpty) {
                            return TransactionUiText.fillRequiredFields;
                          }
                          if (!isCodeFormatValid(value)) {
                            return TransactionUiText.budgetCodeInvalidFormat;
                          }
                          if (isCodeDuplicate(value)) {
                            return TransactionUiText.budgetCodeDuplicate;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: TransactionUiText.budgetSourceNameRequired,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? TransactionUiText.fillRequiredFields
                            : null,
                      ),
                      const SizedBox(height: 8),
                      BuddhistYearField.input(
                        controller: yearCtrl,
                        label: TransactionUiText.fiscalYearBuddhistRequired,
                        required: true,
                        minYear: 2500,
                        maxYear: BuddhistYearField.toBuddhist(
                            DateTime.now().year + 10),
                      ),
                      const SizedBox(height: 8),
                      AppDropdownField<String>(
                        label: TransactionUiText.budgetCategory,
                        value: selectedType,
                        items: budgetTypes
                            .map((t) => AppDropdownItem(value: t, label: t))
                            .toList(),
                        onChanged: (v) => setStateDialog(() {
                          selectedType = v ?? TransactionUiText.budgetTypeGov;
                        }),
                      ),
                      const SizedBox(height: 8),
                      AppLookupPickerField<String>(
                        label: TransactionUiText.moneyGroupRequiredLabel,
                        hint: TransactionUiText.moneyGroupSelectHint,
                        required: true,
                        value: selectedMoneyGroup,
                        clearable: false,
                        items: moneyGroups
                            .map((g) => AppDropdownItem<String>(
                                  value: g.id,
                                  label: g.name,
                                ))
                            .toList(),
                        onChanged: (v) => setStateDialog(() {
                          selectedMoneyGroup = v;
                        }),
                        validator: (v) => (v == null || v.isEmpty)
                            ? TransactionUiText.moneyGroupRequired
                            : null,
                      ),
                      const SizedBox(height: 8),
                      // ─── บัญชีธนาคารที่ผูกกับแหล่งเงิน ────────────────────────────────────────
                      AppLookupPickerField<String>(
                        label: 'บัญชีธนาคารที่ผูกกับแหล่งเงินนี้',
                        helperText:
                            'ใช้เป็นบัญชีรับ/จ่าย default สำหรับทุกเอกสารที่ใช้แหล่งเงินนี้',
                        hint: 'เลือกบัญชีธนาคาร (ไม่บังคับ)',
                        prefixIcon:
                            const Icon(Icons.account_balance_rounded, size: 18),
                        value: selectedBankAccount ?? '',
                        clearable: false,
                        items: [
                          const AppDropdownItem<String>(
                            value: '',
                            label: '— ไม่ระบุ —',
                          ),
                          ...bankAccounts.map((b) => AppDropdownItem<String>(
                                value: b.id,
                                label: b.name,
                              )),
                        ],
                        onChanged: (v) => setStateDialog(() {
                          selectedBankAccount =
                              (v == null || v.isEmpty) ? null : v;
                        }),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setStateDialog(() {
                              codeCtrl.text =
                                  generateCode(selectedType, yearCtrl.text);
                            });
                          },
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text(TransactionUiText.autoGenerateCode),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                            labelText: TransactionUiText.description),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(TransactionUiText.cancel),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                showAutoDismissAlert(
                                  ctx,
                                  TransactionUiText.warning,
                                  TransactionUiText.invalidDataPleaseCheck,
                                  2,
                                );
                                return;
                              }
                              Navigator.pop(
                                ctx,
                                BudgetSourceFormResult(
                                  code: codeCtrl.text.trim().toUpperCase(),
                                  name: nameCtrl.text.trim(),
                                  fiscalYear: yearCtrl.text.trim(),
                                  budgetType: selectedType,
                                  refMoneyGroup: selectedMoneyGroup,
                                  description: descCtrl.text.trim().isEmpty
                                      ? null
                                      : descCtrl.text.trim(),
                                  refBankAccount: selectedBankAccount,
                                ),
                              );
                            },
                            child: const Text(TransactionUiText.save),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
    },
  );

  return result;
}
