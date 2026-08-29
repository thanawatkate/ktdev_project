import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/dialog/confirm_dialog.dart';

/// แจ้งว่ายังไม่มีคำนำหน้า และให้ไปหน้าจัดการคำนำหน้า
class NoPrefixPromptDialog extends StatelessWidget {
  const NoPrefixPromptDialog({
    super.key,
    required this.onGoManagePrefix,
  });

  final VoidCallback onGoManagePrefix;

  void _onPrimary(BuildContext context) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => onGoManagePrefix());
  }

  @override
  Widget build(BuildContext context) {
    return ConfirmDialog(
      isDestructive: false,
      title: TransactionUiText.prefixNoDataDialogTitle,
      message: TransactionUiText.prefixNoDataDialogBody,
      confirmText: TransactionUiText.prefixGoManage,
      confirmColor: Theme.of(context).colorScheme.primary,
      onConfirm: () => _onPrimary(context),
    );
  }
}
