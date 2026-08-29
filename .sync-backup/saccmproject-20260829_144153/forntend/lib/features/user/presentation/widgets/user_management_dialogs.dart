import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

Future<String?> showResetPasswordDialog({
  required BuildContext context,
  required String username,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      child: AdaptiveContentSheet(
        title: '${TransactionUiText.changePassword}: $username',
        child: const _ResetPasswordDialog(),
      ),
    ),
  );
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.passwordMinLength)),
      );
      return;
    }
    Navigator.pop(context, _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppTheme.sp16,
        0,
        AppTheme.sp16,
        MediaQuery.viewInsetsOf(context).bottom + AppTheme.sp16,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInput(
                label: TransactionUiText.newPassword,
                controller: _passwordCtrl,
                action: const AppInputAction.password(),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppTheme.sp12),
              _SheetActionButtons(
                primaryLabel: TransactionUiText.changePassword,
                onPrimary: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<int?> showEditUserRoleDialog({
  required BuildContext context,
  required String username,
  required List<Map<String, dynamic>> groups,
  required String? initialGroupId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      child: AdaptiveContentSheet(
        title: '${TransactionUiText.editUserRole}: $username',
        child: _EditUserRoleDialog(
          groups: groups,
          initialGroupId: initialGroupId,
        ),
      ),
    ),
  );
}

class _EditUserRoleDialog extends StatefulWidget {
  const _EditUserRoleDialog({
    required this.groups,
    required this.initialGroupId,
  });

  final List<Map<String, dynamic>> groups;
  final String? initialGroupId;

  @override
  State<_EditUserRoleDialog> createState() => _EditUserRoleDialogState();
}

class _EditUserRoleDialogState extends State<_EditUserRoleDialog> {
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.initialGroupId;
  }

  void _submit() {
    final groupId = int.tryParse(_selectedGroupId ?? '');
    if (groupId == null) return;
    Navigator.pop(context, groupId);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppTheme.sp16,
        0,
        AppTheme.sp16,
        MediaQuery.viewInsetsOf(context).bottom + AppTheme.sp16,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppLookupPickerField<String>(
                label: TransactionUiText.userGroup,
                value: _selectedGroupId,
                clearable: false,
                items: widget.groups
                    .map(
                      (g) => AppDropdownItem<String>(
                        value: g['id'].toString(),
                        label: (g['nameen'] ?? '').toString(),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedGroupId = v),
              ),
              const SizedBox(height: AppTheme.sp12),
              _SheetActionButtons(
                primaryLabel: TransactionUiText.save,
                onPrimary: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetActionButtons extends StatelessWidget {
  const _SheetActionButtons({
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final isWide = box.maxWidth >= 520;
        final cancel = AppButton.outlined(
          label: TransactionUiText.cancel,
          fullWidth: !isWide,
          onPressed: () => Navigator.pop(context),
        );
        final primary = AppButton.primary(
          label: primaryLabel,
          fullWidth: !isWide,
          onPressed: onPrimary,
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cancel,
              const SizedBox(height: AppTheme.sp8),
              primary,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(width: 140, child: cancel),
            const SizedBox(width: AppTheme.sp8),
            SizedBox(width: 180, child: primary),
          ],
        );
      },
    );
  }
}
