import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';
import 'package:saccm/widgets/widgets.dart';

class BudgetSourceAmountsResult {
  final double budgetAmount;
  final double broughtForwardAmount;

  const BudgetSourceAmountsResult({
    required this.budgetAmount,
    required this.broughtForwardAmount,
  });
}

Future<BudgetSourceAmountsResult?> showBudgetSourceAmountsDialog({
  required BuildContext context,
  required BudgetSourceModel item,
}) async {
  final budgetCtrl = TextEditingController(
    text: item.budgetAmount == 0 ? '' : item.budgetAmount.toString(),
  );
  final broughtCtrl = TextEditingController(
    text: item.broughtForwardAmount == 0
        ? ''
        : item.broughtForwardAmount.toString(),
  );

  final result = await showModalBottomSheet<BudgetSourceAmountsResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final fmt = NumberFormat('#,##0.00');
      return StatefulBuilder(builder: (ctx, setSt) {
        double parseMoney(String s) =>
            double.tryParse(s.trim().replaceAll(',', '')) ?? 0;
        final b = parseMoney(budgetCtrl.text);
        final bf = parseMoney(broughtCtrl.text);
        final total = b + bf;
        final remainingAvail = total - item.usedAmount - item.reservedAmount;
        return SafeArea(
          child: AdaptiveContentSheet(
            title: TransactionUiText.menuBudgetAmounts,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${item.code} · ${item.name}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    Text(
                      '${TransactionUiText.fiscalYearPrefix}${item.fiscalYear}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: broughtCtrl,
                      label: TransactionUiText.broughtForwardBudget,
                      hint: '0.00',
                      action: const AppInputAction.number(allowDecimal: true),
                      textAlign: TextAlign.right,
                      onChanged: (_) => setSt(() {}),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TransactionUiText.broughtForwardBudgetHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: budgetCtrl,
                      label: TransactionUiText.budgetAmountBaht,
                      hint: '0.00',
                      action: const AppInputAction.number(allowDecimal: true),
                      textAlign: TextAlign.right,
                      onChanged: (_) => setSt(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${TransactionUiText.totalBudgetEnvelope}: ${fmt.format(total)} ${TransactionUiText.baht}',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${TransactionUiText.used}: ${fmt.format(item.usedAmount)} ${TransactionUiText.baht} · '
                      '${TransactionUiText.budgetDashboardLegendReserved}: ${fmt.format(item.reservedAmount)} ${TransactionUiText.baht}\n'
                      '${TransactionUiText.remaining}: ${fmt.format(remainingAvail)} ${TransactionUiText.baht}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
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
                            Navigator.pop(
                              ctx,
                              BudgetSourceAmountsResult(
                                budgetAmount: b,
                                broughtForwardAmount: bf,
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
        );
      });
    },
  );

  budgetCtrl.dispose();
  broughtCtrl.dispose();
  return result;
}
