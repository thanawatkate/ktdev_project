import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/widgets/widgets.dart';

class ApprovalDecisionDialog extends StatefulWidget {
  const ApprovalDecisionDialog({
    super.key,
    required this.title,
    required this.docNoText,
    this.amountText,
    required this.inputLabel,
    required this.cancelText,
    required this.confirmText,
    required this.confirmButtonColor,
    this.requireInput = false,
    this.requireInputMessage,
  });

  final String title;
  final String docNoText;
  final String? amountText;
  final String inputLabel;
  final String cancelText;
  final String confirmText;
  final Color confirmButtonColor;
  final bool requireInput;
  final String? requireInputMessage;

  @override
  State<ApprovalDecisionDialog> createState() => _ApprovalDecisionDialogState();
}

class _ApprovalDecisionDialogState extends State<ApprovalDecisionDialog> {
  static const _fontFamily = 'Kanit';
  final TextEditingController _inputController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _inputController.text.trim();
    if (widget.requireInput && text.isEmpty) {
      setState(() {
        _errorText = widget.requireInputMessage ?? '';
      });
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AdaptiveContentSheet(
        title: widget.title,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.docNoText,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: c.textPrimary,
                ),
              ),
              if ((widget.amountText ?? '').isNotEmpty) ...[
                const SizedBox(height: AppTheme.sp4),
                Text(
                  widget.amountText!,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    color: c.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.sp8),
              AppInput(
                controller: _inputController,
                label: widget.inputLabel,
                maxLines: widget.requireInput ? 3 : 1,
                textInputAction: widget.requireInput
                    ? TextInputAction.newline
                    : TextInputAction.done,
              ),
              if ((_errorText ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.sp8),
                  child: Text(
                    _errorText!,
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: AppTheme.sp16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      widget.cancelText,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sp8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.confirmButtonColor,
                    ),
                    onPressed: _submit,
                    child: Text(
                      widget.confirmText,
                      style: const TextStyle(fontFamily: _fontFamily),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
