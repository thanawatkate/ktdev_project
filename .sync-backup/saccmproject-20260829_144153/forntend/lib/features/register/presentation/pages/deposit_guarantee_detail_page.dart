import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/utils/pdf_print.dart';
import 'package:saccm/core/utils/single_open_navigation.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/forms/data/datasources/form_local_data_source.dart';
import 'package:saccm/features/forms/data/datasources/form_remote_data_source.dart';
import 'package:saccm/features/forms/presentation/widgets/voucher_receive_form.dart';
import 'package:saccm/features/forms/presentation/widgets/withholding_tax_form.dart';
import 'package:saccm/features/register/presentation/pages/deposit_guarantee_edit_page.dart';
import 'package:saccm/features/setting/data/datasources/school_profile_local_data_source.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/expense/presentation/providers/expense_provider.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/features/register/data/repositories/deposit_register_repository_offline.dart';
import 'package:saccm/features/register/presentation/pages/deposit_guarantee_settle_page.dart';
import 'package:saccm/features/register/presentation/widgets/_simple_register_tab_base.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ดูรายละเอียดทะเบียนเงินประกัน/ภาษีหัก ณ ที่จ่าย
class DepositGuaranteeDetailPage extends StatefulWidget {
  const DepositGuaranteeDetailPage({
    super.key,
    required this.dio,
    required this.depositId,
    this.initialRow,
  });

  final Dio dio;
  final String depositId;
  final Map<String, dynamic>? initialRow;

  @override
  State<DepositGuaranteeDetailPage> createState() =>
      _DepositGuaranteeDetailPageState();
}

class _DepositGuaranteeDetailPageState
    extends State<DepositGuaranteeDetailPage> {
  static const _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _local = RegisterLocalDataSource();

  Map<String, dynamic>? _row;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _row = widget.initialRow;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _row ??= await _local.getDepositById(widget.depositId);
      if (_row == null) {
        _error = TransactionUiText.registerNoData;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSettle() async {
    final row = _row;
    if (row == null) return;
    final ok = await SingleOpenNavigation.push<bool>(
      context,
      key: 'deposit_guarantee.settle',
      route: MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ExpenseProvider(),
          child: DepositGuaranteeSettlePage(dio: widget.dio, deposit: row),
        ),
      ),
    );
    if (ok == true && mounted) {
      await _load();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteIfAllowed() async {
    final row = _row;
    if (row == null) return;
    if (row['status']?.toString() != 'holding') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            TransactionUiText.cannotDelete,
            style: TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: TransactionUiText.deleteItem,
        message: TransactionUiText.registerDepositDeleteConfirm,
        confirmText: TransactionUiText.delete,
        icon: const Icon(Icons.delete_outline, size: 28),
      ),
    );
    if (confirmed != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      await ServiceLocator.instance
          .get<DepositRegisterRepositoryOffline>()
          .deleteDeposit(
            id: row['id']?.toString() ?? '',
            token: token,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            TransactionUiText.registerDepositDeleteSuccess,
            style: TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _typeLabel(String? raw) {
    switch (raw) {
      case 'contract_guarantee':
        return TransactionUiText.registerDepositTypeContractGuarantee;
      case 'withholding_tax':
        return TransactionUiText.registerDepositTypeWithholdingTax;
      case 'other':
        return TransactionUiText.registerDepositTypeOther;
      default:
        return raw ?? '-';
    }
  }

  Future<void> _openVoucherForm(
    BuildContext context,
    Map<String, dynamic> row,
  ) async {
    final localDs = FormLocalDataSource();
    final personnel = await localDs.getActivePersonnelOptions();
    if (!context.mounted) return;
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: AdaptiveContentSheet(
          title: TransactionUiText.formsCardVoucherReceiveTitle,
          child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: VoucherReceiveForm(
              initialDocNo: row['income_docno']?.toString(),
              personnelOptions: personnel,
            ),
          ),
        ),
      ),
    );
    if (body == null || !context.mounted) return;
    await _generateLinkedForm(context, 'voucher-receive', body);
  }

  Future<void> _openWhtForm(
    BuildContext context,
    Map<String, dynamic> row,
  ) async {
    final localDs = FormLocalDataSource();
    final personnel = await localDs.getActivePersonnelOptions();
    if (!context.mounted) return;
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: AdaptiveContentSheet(
          title: TransactionUiText.formsCardWithholdingTaxTitle,
          child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: WithholdingTaxForm(personnelOptions: personnel),
          ),
        ),
      ),
    );
    if (body == null || !context.mounted) return;
    await _generateLinkedForm(context, 'withholding-tax', body);
  }

  Future<void> _generateLinkedForm(
    BuildContext context,
    String formKey,
    Map<String, dynamic> body,
  ) async {
    await printGeneratedPdf(
      context: context,
      buildDocument: () async {
        final school = await SchoolProfileLocalDataSourceImpl().load();
        body['school_name'] = school.name;
        final ds = FormRemoteDataSource();
        final bytes = await ds.generate(formKey, body);
        final filename =
            '${formKey}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        return PdfPrintDocument(bytes: bytes, filename: filename);
      },
    );
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'holding':
        return TransactionUiText.registerDepositStatusHolding;
      case 'returned':
        return TransactionUiText.registerDepositStatusReturned;
      case 'submitted':
        return TransactionUiText.registerDepositStatusSubmitted;
      case 'forfeited':
        return TransactionUiText.registerDepositStatusForfeited;
      default:
        return raw;
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sp8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: _fontFamily, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final row = _row;
    final status = row?['status']?.toString() ?? '';
    final auth = context.watch<SimpleAuthProvider>();
    final canSettle =
        status == 'holding' && auth.can(PermissionKey.registerDepositSettle);
    final canEdit =
        status == 'holding' && auth.can(PermissionKey.registerDepositUpdate);
    final canDelete = status == 'holding' &&
        auth.can(PermissionKey.registerDepositDelete) &&
        (row?['ref_expense_id'] == null ||
            row!['ref_expense_id'].toString().isEmpty);

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          title: Text(
            TransactionUiText.registerDepositDetailTitle,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          backgroundColor: c.cardWhite,
          elevation: 0,
          actions: [
            if (canEdit)
              IconButton(
                tooltip: TransactionUiText.edit,
                icon: Icon(Icons.edit_outlined, color: c.textSecondary),
                onPressed: () async {
                  final ok = await SingleOpenNavigation.push<bool>(
                    context,
                    key: 'deposit_guarantee.edit',
                    route: MaterialPageRoute(
                      builder: (_) => DepositGuaranteeEditPage(deposit: row!),
                    ),
                  );
                  if (ok == true) _load();
                },
              ),
            if (canDelete)
              IconButton(
                tooltip: TransactionUiText.delete,
                icon: Icon(Icons.delete_outline, color: c.expenseRed),
                onPressed: _deleteIfAllowed,
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.cardBorder),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!, style: TextStyle(color: c.expenseRed)))
                : row == null
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.sp16),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxResponsiveFormWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TransactionFormHeader(
                                  icon: Icons.account_balance_wallet_outlined,
                                  iconColor:
                                      Theme.of(context).colorScheme.primary,
                                  iconBgColor: c.iconBgLoan,
                                  title: TransactionUiText
                                      .registerDepositDetailTitle,
                                  subtitle: TransactionUiText
                                      .registerDepositDetailSection,
                                  quickHint: _statusLabel(status),
                                  hintAccentColor:
                                      Theme.of(context).colorScheme.primary,
                                  hintBorderColor: c.cardBorder,
                                  textPrimaryColor: c.textPrimary,
                                  showQuickHint: false,
                                ),
                                const SizedBox(height: AppTheme.sp16),
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.sp16),
                                  decoration: BoxDecoration(
                                    color: c.cardWhite,
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.r16),
                                    border: Border.all(color: c.cardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        TransactionUiText
                                            .registerDepositDetailSection,
                                        style: TextStyle(
                                          fontFamily: _fontFamily,
                                          fontWeight: FontWeight.w700,
                                          color: c.navy,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp8),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositColDocNo,
                                        row['docno']?.toString() ?? '-',
                                      ),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositColDate,
                                        SimpleRegisterTabBase.formatThaiDate(
                                          row['docdate']?.toString(),
                                        ),
                                      ),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositColType,
                                        _typeLabel(
                                            row['deposit_type']?.toString()),
                                      ),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositColAmount,
                                        '${SimpleRegisterTabBase.formatNumber(row['amount'])} ${TransactionUiText.baht}',
                                      ),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositColParty,
                                        row['party_name']?.toString() ??
                                            row['party_name_snapshot']
                                                ?.toString() ??
                                            '-',
                                      ),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositContractNoLabel,
                                        row['contract_no']?.toString() ?? '-',
                                      ),
                                      _infoRow(
                                        TransactionUiText.registerDepositColDue,
                                        SimpleRegisterTabBase.formatThaiDate(
                                          row['due_date']?.toString(),
                                        ),
                                      ),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositColStatus,
                                        _statusLabel(status),
                                      ),
                                      if ((row['detail']?.toString() ?? '')
                                          .isNotEmpty)
                                        _infoRow(
                                          TransactionUiText.detail,
                                          row['detail']?.toString() ?? '',
                                        ),
                                      const SizedBox(height: AppTheme.sp16),
                                      Text(
                                        TransactionUiText
                                            .registerDepositDetailLedgerSection,
                                        style: TextStyle(
                                          fontFamily: _fontFamily,
                                          fontWeight: FontWeight.w700,
                                          color: c.navy,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp8),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositColIncomeDoc,
                                        row['income_docno']?.toString() ??
                                            TransactionUiText
                                                .registerDepositNoIncomeDoc,
                                      ),
                                      _infoRow(
                                        TransactionUiText
                                            .registerDepositColExpenseDoc,
                                        row['expense_docno']?.toString() ??
                                            TransactionUiText
                                                .registerDepositNoIncomeDoc,
                                      ),
                                      if (status != 'holding') ...[
                                        const SizedBox(height: AppTheme.sp16),
                                        Text(
                                          TransactionUiText
                                              .registerDepositDetailSettleSection,
                                          style: TextStyle(
                                            fontFamily: _fontFamily,
                                            fontWeight: FontWeight.w700,
                                            color: c.navy,
                                          ),
                                        ),
                                        const SizedBox(height: AppTheme.sp8),
                                        _infoRow(
                                          TransactionUiText
                                              .registerDepositSettledDocNo,
                                          row['settled_docno']?.toString() ??
                                              '-',
                                        ),
                                        if ((row['settled_remark']
                                                    ?.toString() ??
                                                '')
                                            .isNotEmpty)
                                          _infoRow(
                                            TransactionUiText.notePrefix.trim(),
                                            row['settled_remark']?.toString() ??
                                                '',
                                          ),
                                      ],
                                      const SizedBox(height: AppTheme.sp16),
                                      Text(
                                        TransactionUiText
                                            .registerDepositLinkedFormsSection,
                                        style: TextStyle(
                                          fontFamily: _fontFamily,
                                          fontWeight: FontWeight.w700,
                                          color: c.navy,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.sp8),
                                      if ((row['income_docno']?.toString() ??
                                              '')
                                          .isNotEmpty)
                                        AppButton.outlined(
                                          label: TransactionUiText
                                              .registerDepositFormVoucher,
                                          icon: const Icon(
                                              Icons.receipt_long_outlined),
                                          onPressed: () =>
                                              _openVoucherForm(context, row),
                                        ),
                                      if (row['deposit_type']?.toString() ==
                                          'withholding_tax')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: AppTheme.sp8),
                                          child: AppButton.outlined(
                                            label: TransactionUiText
                                                .registerDepositFormWht,
                                            icon: const Icon(
                                                Icons.description_outlined),
                                            onPressed: () =>
                                                _openWhtForm(context, row),
                                          ),
                                        ),
                                      if (canSettle) ...[
                                        const SizedBox(height: AppTheme.sp24),
                                        AppButton.primary(
                                          label: TransactionUiText
                                              .registerDepositActionSettle,
                                          icon: const Icon(Icons.undo_outlined,
                                              size: 18),
                                          onPressed: _openSettle,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
      ),
    );
  }
}
