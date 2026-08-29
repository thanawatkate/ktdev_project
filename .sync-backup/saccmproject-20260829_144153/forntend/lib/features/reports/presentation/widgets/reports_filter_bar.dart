import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

class ReportsYearFilterBar extends StatelessWidget {
  const ReportsYearFilterBar({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: BuddhistYearField.picker(
              controller: controller,
              required: false,
              maxYear: BuddhistYearField.toBuddhist(DateTime.now().year + 10),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSubmit,
            child: const Text(TransactionUiText.view),
          ),
        ],
      ),
    );
  }
}

class ReportsDateFilterBar extends StatelessWidget {
  const ReportsDateFilterBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.trailing,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      color: c.cardWhite,
      child: Row(
        children: [
          Expanded(
            child: AppInput(
              label: TransactionUiText.reportsDateLabel,
              controller: controller,
              action: AppInputAction.date(
                initialValue: ThaiDateFormatter.parse(controller.text),
                clearable: false,
                onChanged: (date) {
                  if (date == null) return;
                  controller.text = ThaiDateFormatter.toIsoDate(date);
                  onSubmit();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSubmit,
            child: const Text(TransactionUiText.view),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}
