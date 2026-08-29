import 'package:flutter/material.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/pdf_print.dart';

import 'app_button.dart';

class AppPdfPrintButton extends StatefulWidget {
  const AppPdfPrintButton({
    super.key,
    required this.buildDocument,
    this.label = TransactionUiText.formsPrintPdfAction,
    this.enabled = true,
    this.fullWidth = true,
    this.variant = AppButtonVariant.primary,
    this.icon = const Icon(Icons.print_outlined, size: 18),
    this.onBusyChanged,
  });

  final Future<PdfPrintDocument> Function() buildDocument;
  final String label;
  final bool enabled;
  final bool fullWidth;
  final AppButtonVariant variant;
  final Widget? icon;
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<AppPdfPrintButton> createState() => _AppPdfPrintButtonState();
}

class _AppPdfPrintButtonState extends State<AppPdfPrintButton> {
  bool _busy = false;

  Future<void> _print() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    try {
      await printGeneratedPdf(
        context: context,
        buildDocument: widget.buildDocument,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: widget.label,
      icon: widget.icon,
      fullWidth: widget.fullWidth,
      variant: widget.variant,
      isLoading: _busy,
      onPressed: widget.enabled && !_busy ? _print : null,
    );
  }
}

class AppPdfPrintIconButton extends StatefulWidget {
  const AppPdfPrintIconButton({
    super.key,
    required this.buildDocument,
    this.enabled = true,
    this.tooltip = TransactionUiText.formsPrintPdfTooltip,
    this.onBusyChanged,
  });

  final Future<PdfPrintDocument> Function() buildDocument;
  final bool enabled;
  final String tooltip;
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<AppPdfPrintIconButton> createState() => _AppPdfPrintIconButtonState();
}

class _AppPdfPrintIconButtonState extends State<AppPdfPrintIconButton> {
  bool _busy = false;

  Future<void> _print() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    try {
      await printGeneratedPdf(
        context: context,
        buildDocument: widget.buildDocument,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: widget.enabled && !_busy ? _print : null,
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.print_outlined),
    );
  }
}
