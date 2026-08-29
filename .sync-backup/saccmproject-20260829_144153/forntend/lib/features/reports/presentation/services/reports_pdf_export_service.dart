import 'package:saccm/core/utils/pdf_print.dart';
import 'package:saccm/features/reports/presentation/services/reports_pdf_export_isolate.dart';
import 'package:saccm/features/reports/presentation/services/reports_pdf_fonts.dart';
import 'package:saccm/features/setting/domain/entities/school_profile.dart';

/// Client-side PDF generation for official finance reports (pages 32–34, 33).
class ReportsPdfExportService {
  Future<void> _ensureFonts() => ReportsPdfFonts.preload();

  Future<PdfPrintDocument> buildAnnualSummaryPdf({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String fiscalYearText,
  }) async {
    await _ensureFonts();
    final fy = data['fiscal_year']?.toString() ?? fiscalYearText;
    final job = AnnualSummaryPdfJob(
      regularFont: ReportsPdfFonts.regularBytes!,
      boldFont: ReportsPdfFonts.boldBytes!,
      schoolName: schoolProfile.name,
      data: data,
      fiscalYearText: fiscalYearText,
    );
    final bytes = await runPdfInBackground(() => buildAnnualSummaryPdfBytes(job));
    return PdfPrintDocument(bytes: bytes, filename: 'annual_summary_$fy.pdf');
  }

  Future<PdfPrintDocument> buildDailyBalancePdf({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String reportDate,
  }) async {
    await _ensureFonts();
    final job = DailyBalancePdfJob(
      regularFont: ReportsPdfFonts.regularBytes!,
      boldFont: ReportsPdfFonts.boldBytes!,
      schoolName: schoolProfile.name,
      data: data,
      reportDate: reportDate,
    );
    final bytes = await runPdfInBackground(() => buildDailyBalancePdfBytes(job));
    return PdfPrintDocument(
      bytes: bytes,
      filename: 'daily_balance_$reportDate.pdf',
    );
  }

  Future<PdfPrintDocument> buildBankReconciliationPdf({
    required SchoolProfile schoolProfile,
    required Map<String, dynamic> data,
    required String reportDate,
  }) async {
    await _ensureFonts();
    final job = BankReconciliationPdfJob(
      regularFont: ReportsPdfFonts.regularBytes!,
      boldFont: ReportsPdfFonts.boldBytes!,
      schoolName: schoolProfile.name,
      data: data,
      reportDate: reportDate,
    );
    final bytes =
        await runPdfInBackground(() => buildBankReconciliationPdfBytes(job));
    return PdfPrintDocument(
      bytes: bytes,
      filename: 'bank_reconciliation_$reportDate.pdf',
    );
  }
}
