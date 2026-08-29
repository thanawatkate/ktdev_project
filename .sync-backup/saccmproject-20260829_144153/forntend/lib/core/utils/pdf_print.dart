import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

enum PdfPrintOutcome {
  printed,
  canceled,
  unavailable,
}

class PdfPrintDocument {
  const PdfPrintDocument({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;
}

Future<PdfPrintOutcome> printPdfBytes({
  required BuildContext context,
  required Uint8List bytes,
  required String filename,
}) async {
  final info = await Printing.info();
  if (!info.canPrint) return PdfPrintOutcome.unavailable;
  if (!context.mounted) return PdfPrintOutcome.canceled;

  Future<Uint8List> buildPdf(_) async => bytes;
  final name = filename.endsWith('.pdf') ? filename : '$filename.pdf';

  if (!kIsWeb && info.canListPrinters && info.directPrint) {
    final printer = await Printing.pickPrinter(
      context: context,
      title: TransactionUiText.formsPrintSelectPrinterTitle,
    );
    if (!context.mounted || printer == null) return PdfPrintOutcome.canceled;

    final printed = await Printing.directPrintPdf(
      printer: printer,
      onLayout: buildPdf,
      name: name,
      dynamicLayout: info.dynamicLayout,
      usePrinterSettings: true,
    );
    return printed ? PdfPrintOutcome.printed : PdfPrintOutcome.canceled;
  }

  final printed = await Printing.layoutPdf(
    onLayout: buildPdf,
    name: name,
    dynamicLayout: info.dynamicLayout,
    usePrinterSettings: !kIsWeb,
  );
  return printed ? PdfPrintOutcome.printed : PdfPrintOutcome.canceled;
}

Future<PdfPrintOutcome?> printGeneratedPdf({
  required BuildContext context,
  required Future<PdfPrintDocument> Function() buildDocument,
}) async {
  try {
    final document = await buildDocument();
    if (!context.mounted) return null;

    final outcome = await printPdfBytes(
      context: context,
      bytes: document.bytes,
      filename: document.filename,
    );
    if (!context.mounted) return outcome;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pdfPrintOutcomeMessage(outcome))),
    );
    return outcome;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${TransactionUiText.formsPrintFailedPrefix} $e'),
        ),
      );
    }
    return null;
  }
}

String pdfPrintOutcomeMessage(PdfPrintOutcome outcome) {
  switch (outcome) {
    case PdfPrintOutcome.printed:
      return TransactionUiText.formsPrintSuccess;
    case PdfPrintOutcome.canceled:
      return TransactionUiText.formsPrintCanceled;
    case PdfPrintOutcome.unavailable:
      return TransactionUiText.formsPrintUnavailable;
  }
}
