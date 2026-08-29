// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/core/utils/pdf_print.dart';
import 'package:saccm/features/forms/data/datasources/form_local_data_source.dart';
import 'package:saccm/features/forms/data/datasources/form_remote_data_source.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/widgets/layout/embedded_home_scaffold.dart';
import 'package:saccm/widgets/widgets.dart';

import '../widgets/receipt_substitute_form.dart';
import '../widgets/voucher_receive_form.dart';
import '../widgets/withholding_tax_form.dart';
import '../widgets/receipt_attachment_form.dart';

/// หน้าหลัก "แบบฟอร์มเอกสาร"
/// เลือกแบบฟอร์ม → กรอกข้อมูล → ดาวน์โหลด/เปิด PDF
class FormsPage extends StatefulWidget {
  const FormsPage({
    super.key,
    this.embeddedInHome = false,
  });

  final bool embeddedInHome;

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _ds = FormRemoteDataSource();
  final _localDs = FormLocalDataSource();
  bool _busy = false;
  String? _busyMessage;
  List<FormPersonnelOption> _personnelOptions = const [];

  @override
  void initState() {
    super.initState();
    _loadPersonnelOptions();
  }

  Future<void> _loadPersonnelOptions() async {
    try {
      final options = await _localDs.getActivePersonnelOptions();
      if (!mounted) return;
      setState(() => _personnelOptions = options);
    } catch (_) {}
  }

  Future<void> _generate(
    BuildContext context,
    String formKey,
    String title,
    Map<String, dynamic> body,
  ) async {
    setState(() {
      _busy = true;
      _busyMessage = '${TransactionUiText.formsBusyGeneratingPrefix} $title...';
    });
    try {
      await printGeneratedPdf(
        context: context,
        buildDocument: () => _buildFormPrintDocument(formKey, body),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<PdfPrintDocument> _buildFormPrintDocument(
    String formKey,
    Map<String, dynamic> body,
  ) async {
    final bytes = await _ds.generate(formKey, body);
    final fname =
        '${formKey.replaceAll(RegExp(r"[^a-zA-Z0-9]"), "_")}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return PdfPrintDocument(bytes: bytes, filename: fname);
  }

  Future<String?> _generateDocNo({
    required String tableName,
    required DateTime? docDate,
  }) async {
    final date = docDate ?? DateTime.now();
    try {
      final docNo = await _localDs.generateDocNo(
        tableName: tableName,
        docDate: date,
      );
      return docNo == null || docNo.isEmpty ? null : docNo;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return EmbeddedHomeScaffold(
      embeddedInHome: widget.embeddedInHome,
      backgroundColor: c.background,
      standaloneAppBar: AppBar(
        toolbarHeight: 52,
        title: Text(
          TransactionUiText.formsPageTitle,
          style: TextStyle(
            fontFamily: _fontFamily,
            color: c.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.cardBorder),
        ),
      ),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TransactionFormHeader(
                      icon: Icons.description_outlined,
                      iconColor: scheme.primary,
                      iconBgColor: c.iconBgIncome,
                      title: TransactionUiText.formsPageTitle,
                      subtitle: TransactionUiText.formsReviewBeforeGenerate,
                      quickHint: TransactionUiText.formsQuickHint,
                      hintAccentColor: scheme.primary,
                      hintBorderColor: c.cardBorder,
                      textPrimaryColor: c.textPrimary,
                      showQuickHint: false,
                    ),
                    const SizedBox(height: AppTheme.sp16),
                    _formCard(
                      c,
                      icon: Icons.receipt_long_outlined,
                      title: TransactionUiText.formsCardReceiptSubstituteTitle,
                      description: TransactionUiText
                          .formsCardReceiptSubstituteDescription,
                      onTap: _openReceiptSubstitute,
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    _formCard(
                      c,
                      icon: Icons.receipt_outlined,
                      title: TransactionUiText.formsCardVoucherReceiveTitle,
                      description:
                          TransactionUiText.formsCardVoucherReceiveDescription,
                      onTap: _openVoucherReceive,
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    _formCard(
                      c,
                      icon: Icons.account_balance_outlined,
                      title: TransactionUiText.formsCardWithholdingTaxTitle,
                      description:
                          TransactionUiText.formsCardWithholdingTaxDescription,
                      onTap: _openWithholdingTax,
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    _formCard(
                      c,
                      icon: Icons.attach_file_outlined,
                      title: TransactionUiText.formsCardReceiptAttachmentTitle,
                      description: TransactionUiText
                          .formsCardReceiptAttachmentDescription,
                      onTap: _openReceiptAttachment,
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    _formCard(
                      c,
                      icon: Icons.account_balance_wallet_outlined,
                      title: TransactionUiText.formsCardDepositRegisterTitle,
                      description:
                          TransactionUiText.formsCardDepositRegisterDescription,
                      onTap: _openDepositRegister,
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    _formCard(
                      c,
                      icon: Icons.assignment_ind_outlined,
                      title: TransactionUiText.formsCardLoanContractTitle,
                      description:
                          TransactionUiText.formsCardLoanContractDescription,
                      onTap: _openLoanContract,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_busy)
          Container(
            color: Colors.black.withValues(alpha: 0.4),
            alignment: Alignment.center,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_busyMessage ?? TransactionUiText.formsBusyProcessing),
                  ],
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _formCard(
    AppColors c, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: c.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.r16),
        side: BorderSide(color: c.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.r16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.iconBgIncome,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                ),
                child: Icon(icon, color: c.navy, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: c.textHint),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _openFormSheet({
    required String singleOpenKey,
    required Widget child,
  }) {
    return SingleOpenNavigation.showSheet<Map<String, dynamic>>(
      context,
      key: singleOpenKey,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _maxResponsiveFormWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _openReceiptSubstitute() async {
    final body = await _openFormSheet(
      singleOpenKey: 'forms.receipt_substitute',
      child: ReceiptSubstituteForm(personnelOptions: _personnelOptions),
    );
    if (body != null) {
      await _generate(context, 'receipt-substitute',
          TransactionUiText.formsCardReceiptSubstituteTitle, body);
    }
  }

  void _openVoucherReceive() async {
    final canManualDocNoOverride = context
        .read<SimpleAuthProvider>()
        .can(PermissionKey.formsDocNoManualEdit);
    final initialDocNo = await _generateDocNo(
      tableName: 'expense',
      docDate: DateTime.now(),
    );
    if (!mounted) return;
    final body = await _openFormSheet(
      singleOpenKey: 'forms.voucher_receive',
      child: VoucherReceiveForm(
        initialDocNo: initialDocNo,
        allowManualDocNoOverride: canManualDocNoOverride,
        personnelOptions: _personnelOptions,
        onGenerateDocNo: (docDate) => _generateDocNo(
          tableName: 'expense',
          docDate: docDate,
        ),
      ),
    );
    if (body != null) {
      await _generate(context, 'voucher-receive',
          TransactionUiText.formsCardVoucherReceiveTitle, body);
    }
  }

  void _openWithholdingTax() async {
    final body = await _openFormSheet(
      singleOpenKey: 'forms.withholding_tax',
      child: WithholdingTaxForm(personnelOptions: _personnelOptions),
    );
    if (body != null) {
      await _generate(context, 'withholding-tax',
          TransactionUiText.formsCardWithholdingTaxTitle, body);
    }
  }

  void _openDepositRegister() async {
    final school = await SchoolProfileLocalDataSourceImpl().load();
    if (!mounted) return;
    await _generate(
      context,
      'deposit-register',
      TransactionUiText.formsCardDepositRegisterTitle,
      {
        'school_name': school.name,
        'fiscal_year': FiscalYear.currentBuddhist().toString(),
      },
    );
  }

  void _openReceiptAttachment() async {
    final canManualDocNoOverride = context
        .read<SimpleAuthProvider>()
        .can(PermissionKey.formsDocNoManualEdit);
    final initialDocNo = await _generateDocNo(
      tableName: 'expensereq',
      docDate: DateTime.now(),
    );
    if (!mounted) return;
    final body = await _openFormSheet(
      singleOpenKey: 'forms.receipt_attachment',
      child: ReceiptAttachmentForm(
        initialDocNo: initialDocNo,
        allowManualDocNoOverride: canManualDocNoOverride,
        personnelOptions: _personnelOptions,
        onGenerateDocNo: (docDate) => _generateDocNo(
          tableName: 'expensereq',
          docDate: docDate,
        ),
      ),
    );
    if (body != null) {
      await _generate(context, 'receipt-attachment',
          TransactionUiText.formsCardReceiptAttachmentTitle, body);
    }
  }

  void _openLoanContract() async {
    final borrower = TextEditingController();
    final position = TextEditingController();
    final amount = TextEditingController();
    final purpose = TextEditingController();
    final approver = TextEditingController();
    try {
      final body =
          await SingleOpenNavigation.runForNavigator<Map<String, dynamic>>(
        context,
        key: 'forms.loan_contract',
        useRootNavigator: true,
        action: () => showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: false,
          backgroundColor: Colors.transparent,
          builder: (ctx) => SafeArea(
            child: AdaptiveContentSheet(
              title: TransactionUiText.formsCardLoanContractTitle,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  MediaQuery.viewInsetsOf(ctx).bottom + AppTheme.sp16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppInput(
                        controller: borrower,
                        label: TransactionUiText.loanBorrower,
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      AppInput(
                        controller: position,
                        label: TransactionUiText.formsLabelPayerPosition,
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      AppInput(
                        controller: amount,
                        label: TransactionUiText.formsLabelAmount,
                        action: const AppInputAction.number(allowDecimal: true),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      AppInput(
                        controller: purpose,
                        label: TransactionUiText.formsLabelLoanPurpose,
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      AppInput(
                        controller: approver,
                        label: TransactionUiText.formsLabelApproverName,
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppButton.outlined(
                            label: TransactionUiText.cancel,
                            fullWidth: false,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          const SizedBox(width: AppTheme.sp8),
                          AppButton.primary(
                            label: TransactionUiText.formsPrintPdfAction,
                            icon: const Icon(Icons.print_outlined, size: 18),
                            fullWidth: false,
                            onPressed: () => Navigator.pop(ctx, {
                              'docdate': DateTime.now().toIso8601String(),
                              'borrower_name': borrower.text.trim(),
                              'borrower_position': position.text.trim(),
                              'amount': amount.text.trim(),
                              'purpose': purpose.text.trim(),
                              'approver_name': approver.text.trim(),
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      if (body != null && mounted) {
        await _generate(
          context,
          'loan-contract',
          TransactionUiText.formsCardLoanContractTitle,
          body,
        );
      }
    } finally {
      borrower.dispose();
      position.dispose();
      amount.dispose();
      purpose.dispose();
      approver.dispose();
    }
  }
}
