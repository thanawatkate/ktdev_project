import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/dialog/confirm_dialog.dart';

class FormLeaveConfirmDialog extends StatelessWidget {
  const FormLeaveConfirmDialog({
    super.key,
    this.title = TransactionUiText.formUnsavedLeaveTitle,
    this.message = TransactionUiText.formUnsavedLeaveBody,
    this.cancelText = TransactionUiText.formUnsavedStay,
    this.confirmText = TransactionUiText.formUnsavedLeaveWithoutSave,
    this.confirmColor,
  });

  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final Color? confirmColor;

  @override
  Widget build(BuildContext context) {
    return ConfirmDialog(
      isDestructive: false,
      title: title,
      message: message,
      cancelText: cancelText,
      confirmText: confirmText,
      confirmColor: confirmColor ?? Theme.of(context).colorScheme.error,
    );
  }
}

Future<bool> showFormLeaveConfirmDialog(
  BuildContext context, {
  String title = TransactionUiText.formUnsavedLeaveTitle,
  String message = TransactionUiText.formUnsavedLeaveBody,
  String cancelText = TransactionUiText.formUnsavedStay,
  String confirmText = TransactionUiText.formUnsavedLeaveWithoutSave,
  Color? confirmColor,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => FormLeaveConfirmDialog(
          title: title,
          message: message,
          cancelText: cancelText,
          confirmText: confirmText,
          confirmColor:
              confirmColor ?? Theme.of(dialogContext).colorScheme.error,
        ),
      ) ??
      false;
}
