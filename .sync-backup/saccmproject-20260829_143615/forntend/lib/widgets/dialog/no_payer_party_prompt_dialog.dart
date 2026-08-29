import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/dialog/confirm_dialog.dart';

/// แจ้งว่ายังไม่มีผู้จ่ายที่ใช้งาน และให้ไปหน้าจัดการผู้รับ/ผู้จ่าย
///
/// เรียก [onGoAddParty] หลังปิด dialog แล้ว (post-frame) เพื่อให้นำทางปลอดภัย
class NoPayerPartyPromptDialog extends StatelessWidget {
  const NoPayerPartyPromptDialog({
    super.key,
    required this.onGoAddParty,
    this.dialogTitle,
    this.dialogBody,
  });

  final VoidCallback onGoAddParty;

  /// ถ้า null ใช้ข้อความผู้จ่าย (รายรับ)
  final String? dialogTitle;

  /// ถ้า null ใช้ข้อความผู้จ่าย (รายรับ)
  final String? dialogBody;

  void _onPrimary(BuildContext context) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => onGoAddParty());
  }

  @override
  Widget build(BuildContext context) {
    return ConfirmDialog(
      isDestructive: false,
      title: dialogTitle ?? TransactionUiText.receiveFromNoPayerDialogTitle,
      message: dialogBody ?? TransactionUiText.receiveFromNoPayerDialogBody,
      confirmText: TransactionUiText.receiveFromGoAddParty,
      confirmColor: Theme.of(context).colorScheme.primary,
      onConfirm: () => _onPrimary(context),
    );
  }
}
