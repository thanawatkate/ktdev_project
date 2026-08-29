import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/loan/presentation/providers/loan_provider.dart';
import 'package:saccm/features/loan/presentation/providers/repay_loan_provider.dart';
import 'package:saccm/widgets/dialog/form_leave_confirm_dialog.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RepayLoanAddPage extends StatelessWidget {
  const RepayLoanAddPage({
    super.key,
    this.initialData,
    this.embeddedInHome = false,
  });

  final Map<String, dynamic>? initialData;
  final bool embeddedInHome;

  @override
  Widget build(BuildContext context) {
    final existingProvider =
        Provider.of<RepayLoanProvider?>(context, listen: false);
    final child = _RepayLoanAddView(
      initialData: initialData,
      embeddedInHome: embeddedInHome,
    );
    if (existingProvider != null) return child;

    return ChangeNotifierProvider(
      create: (_) => RepayLoanProvider(),
      child: child,
    );
  }
}

class _RepayLoanAddView extends StatefulWidget {
  const _RepayLoanAddView({
    this.initialData,
    this.embeddedInHome = false,
  });

  final Map<String, dynamic>? initialData;
  final bool embeddedInHome;

  @override
  State<_RepayLoanAddView> createState() => _RepayLoanAddPageState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _RepayLoanAddPageState extends State<_RepayLoanAddView> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;
  final _docnoCtrl = TextEditingController();
  final _refLoanCtrl = TextEditingController();
  String _selectedLoanId = '';
  final _amountCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  DateTime _selectedRepayDate = DateTime.now();
  late String _repayDate = DateTime.now().toIso8601String();
  bool _isHandlingBackNavigation = false;
  String _initialDocNo = '';
  String _initialRefLoan = '';
  String _initialAmount = '';
  String _initialRemark = '';
  String _initialRepayDate = '';
  bool get _isEditMode => widget.initialData != null;

  LoanProvider? get _loanProviderOrNull =>
      Provider.of<LoanProvider?>(context, listen: false);

  bool get _hasLoanCatalog => (_loanProviderOrNull?.rows.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _docnoCtrl.text = data['docno']?.toString() ?? '';
      _selectedLoanId = data['refLoan']?.toString() ?? '';
      _amountCtrl.text = data['amount']?.toString() ?? '';
      _remarkCtrl.text = data['remark']?.toString() ?? '';
      final dueDateRaw = data['duedate']?.toString();
      if (dueDateRaw != null && dueDateRaw.isNotEmpty) {
        _repayDate = dueDateRaw;
        final parsed = DateTime.tryParse(dueDateRaw);
        if (parsed != null) _selectedRepayDate = parsed;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loanProvider = _loanProviderOrNull;
      final repayProvider = context.read<RepayLoanProvider>();
      if (loanProvider != null) {
        await loanProvider.loadLoanList();
        if (_selectedLoanId.isNotEmpty) {
          _syncRefLoanDisplayFromCatalog(loanProvider.rows);
        }
      }
      await repayProvider.loadRepayLoanList();
      if (!mounted) return;
      if (!_isEditMode) {
        final now = _selectedRepayDate.toIso8601String().split('T').first;
        final docno = await repayProvider.fetchDocNo(
          tableName: 'repay_loan',
          docDate: now,
        );
        if (mounted && docno != null) _docnoCtrl.text = docno;
      }
      _captureInitialSnapshot();
    });
  }

  @override
  void dispose() {
    _docnoCtrl.dispose();
    _refLoanCtrl.dispose();
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _syncRefLoanDisplayFromCatalog(List<Map<String, dynamic>> loanRows) {
    final row = _loanRowById(_selectedLoanId, loanRows);
    if (row != null) {
      _refLoanCtrl.text = row['docno']?.toString() ?? '';
    }
  }

  void _captureInitialSnapshot() {
    _initialDocNo = _docnoCtrl.text.trim();
    _initialRefLoan = _selectedLoanId;
    _initialAmount = _amountCtrl.text.trim();
    _initialRemark = _remarkCtrl.text.trim();
    _initialRepayDate = _repayDate.trim();
  }

  bool _hasUnsavedChanges() {
    return _docnoCtrl.text.trim() != _initialDocNo ||
        _selectedLoanId != _initialRefLoan ||
        _amountCtrl.text.trim() != _initialAmount ||
        _remarkCtrl.text.trim() != _initialRemark ||
        _repayDate.trim() != _initialRepayDate;
  }

  Map<String, dynamic>? _loanRowById(
    String loanId, [
    List<Map<String, dynamic>>? loanRows,
  ]) {
    final rows =
        loanRows ?? _loanProviderOrNull?.rows ?? const <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final serverId = row['server_id']?.toString() ?? '';
      final docno = row['docno']?.toString() ?? '';
      if (id == loanId || serverId == loanId || docno == loanId) return row;
    }
    return null;
  }

  double _loanAmountById(String loanId) {
    final r = _loanRowById(loanId);
    if (r == null) return 0;
    final principal = double.tryParse(r['amount']?.toString() ?? '0') ?? 0;
    final opening =
        double.tryParse(r['opening_outstanding']?.toString() ?? '0') ?? 0;
    return principal + opening;
  }

  bool _loanExists(String loanId) => _loanRowById(loanId) != null;

  double _repaySumByLoanId(String loanId, {String? excludeRepayId}) {
    final repayRows = context.read<RepayLoanProvider>().rows;
    return repayRows.fold<double>(0, (sum, row) {
      final refLoan = row['refLoan']?.toString() ?? '';
      final rowId = row['id']?.toString();
      final resolvedId = _loanRowById(refLoan)?['id']?.toString() ?? refLoan;
      if (resolvedId != loanId) return sum;
      if (excludeRepayId != null && rowId == excludeRepayId) return sum;
      return sum + (double.tryParse(row['amount']?.toString() ?? '0') ?? 0);
    });
  }

  double _remainingByLoanId(String loanId, {String? excludeRepayId}) {
    final loanAmount = _loanAmountById(loanId);
    final repaid = _repaySumByLoanId(loanId, excludeRepayId: excludeRepayId);
    final remain = loanAmount - repaid;
    return remain < 0 ? 0 : remain;
  }

  bool _isLoanOverdueByLoanId(String loanId, {String? excludeRepayId}) {
    final row = _loanRowById(loanId);
    if (row == null) return false;
    final dueRaw = row['duedate']?.toString() ?? '';
    final due = DateTime.tryParse(dueRaw);
    if (due == null) return false;
    final remaining =
        _remainingByLoanId(loanId, excludeRepayId: excludeRepayId);
    return remaining > 0 &&
        due.isBefore(
          DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day),
        );
  }

  Future<List<AppDropdownItem<String>>> _loadLoanDocLookupItems() async {
    final loanProvider = _loanProviderOrNull;
    if (loanProvider == null) {
      _showSnack(TransactionUiText.providerNotFound);
      return const [];
    }
    await loanProvider.loadLoanList();
    final excludeRepayId =
        _isEditMode ? widget.initialData!['id']?.toString() : null;
    return loanProvider.rows.map((row) {
      final id = row['id']?.toString() ?? '';
      final docno = row['docno']?.toString() ?? id;
      final borrower = row['borrower']?.toString() ?? '-';
      final dueDisplay = _formatDate(row['duedate']?.toString() ?? '');
      final remaining = _remainingByLoanId(id, excludeRepayId: excludeRepayId)
          .toStringAsFixed(2);
      return AppDropdownItem<String>(
        value: id,
        label: docno,
        subtitle: TransactionUiText.repayLoanPickerRowSubtitle(
          borrower: borrower,
          dueDisplay: dueDisplay,
          remaining: remaining,
        ),
      );
    }).toList();
  }

  Future<void> _onRepayDateChanged(DateTime? d) async {
    if (d == null) return;
    setState(() {
      _selectedRepayDate = d;
      _repayDate = d.toIso8601String();
    });
    if (_isEditMode) return;
    final provider = context.read<RepayLoanProvider>();
    final docDate = d.toIso8601String().split('T').first;
    final nextDocNo = await provider.fetchDocNo(
      tableName: 'repay_loan',
      docDate: docDate,
    );
    if (!mounted || nextDocNo == null) return;
    _docnoCtrl.text = nextDocNo;
  }

  Widget _buildRepayDateInput(AppColors c) {
    return AppDateInput(
      initialValue: _selectedRepayDate,
      label: TransactionUiText.date,
      dateFormat: AppDateFormat.thaiBuddhist,
      onChanged: _onRepayDateChanged,
    );
  }

  Widget _buildRepayDocNoInput(AppColors c) {
    return AppInput(
      label: TransactionUiText.docNumber,
      hint: TransactionUiText.autoGenerated,
      helperText: TransactionUiText.docNoAutoHelper,
      readOnly: true,
      controller: _docnoCtrl,
      prefixIcon: const Icon(Icons.tag_rounded),
    );
  }

  Widget _buildRepayRefLoanFields(AppColors c) {
    return ListenableBuilder(
      listenable: _refLoanCtrl,
      builder: (context, _) {
        final hasRef = _selectedLoanId.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppLookupPickerField<String>(
              label: TransactionUiText.repayLoanRefLoanLabel,
              hint: TransactionUiText.repayLoanRefLoanHint,
              helperText: TransactionUiText.repayLoanRefLoanHelperPick,
              value: _selectedLoanId.isEmpty ? null : _selectedLoanId,
              displayLabel:
                  _refLoanCtrl.text.trim().isEmpty ? null : _refLoanCtrl.text,
              clearable: false,
              pickerTitle: TransactionUiText.repayLoanPickerTitle,
              searchHint: TransactionUiText.repayLoanPickerSearchHint,
              emptyText: TransactionUiText.repayLoanPickerNoLoansInDb,
              loadItems: _loadLoanDocLookupItems,
              onChanged: (v) {
                final loanId = v?.trim() ?? '';
                if (loanId.isEmpty) return;
                final row = _loanRowById(loanId);
                setState(() {
                  _selectedLoanId = loanId;
                  _refLoanCtrl.text = row?['docno']?.toString() ?? loanId;
                });
              },
              prefixIcon: const Icon(Icons.receipt_long_rounded),
            ),
            if (hasRef && _loanExists(_selectedLoanId)) ...[
              const SizedBox(height: AppTheme.sp8),
              _buildLoanStatusHint(c, _selectedLoanId),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRepayAmountInput(AppColors c) {
    return AppInput(
      label: TransactionUiText.amount,
      hint: '0.00',
      required: true,
      helperText: TransactionUiText.positiveAmountHelper,
      controller: _amountCtrl,
      action: const AppInputAction.number(allowDecimal: true),
      textAlign: TextAlign.right,
      prefixIcon: const Icon(Icons.attach_money_rounded),
    );
  }

  Widget _buildRepayRemarkInput(AppColors c) {
    return AppInput(
      label: TransactionUiText.remark,
      hint: TransactionUiText.remarkHint,
      controller: _remarkCtrl,
      minLines: 2,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      prefixIcon: const Icon(Icons.edit_note_rounded),
    );
  }

  Widget _buildSummaryActions(AppColors c) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _amountCtrl,
        context.read<RepayLoanProvider>(),
      ]),
      builder: (context, _) {
        final repayLoading = context.read<RepayLoanProvider>().isLoading;
        final isReady = _isFormReady();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSaveReadinessHint(c, isReady),
            const SizedBox(height: AppTheme.sp8),
            TransactionSummaryActions(
              totalAmount:
                  double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
              totalLabel: TransactionUiText.totalAmount,
              amountColor: c.loanAmber,
              cardColor: c.cardWhite,
              borderColor: c.cardBorder,
              textSecondaryColor: c.textSecondary,
              currencyLabel: TransactionUiText.baht,
              saveLabel: _isEditMode
                  ? TransactionUiText.saveEdit
                  : TransactionUiText.save,
              isSaving: repayLoading,
              onSave: _onSave,
              isSaveEnabled: isReady,
              saveDisabledHint: isReady ? null : _buildMissingRequiredText(),
              isEditMode: _isEditMode,
              cancelLabel: TransactionUiText.cancel,
              onCancel: _handleBackNavigation,
              showSaveButton: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
    AppColors c, {
    required IconData icon,
    required String title,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp12,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final contentWidth = _cardContentWidth(box.maxWidth);
          final columnCount = _responsiveColumnCount(contentWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                c,
                icon: Icons.description_outlined,
                title: TransactionUiText.documentInfo,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(child: _buildRepayDateInput(c)),
                    _ResponsiveFormField(child: _buildRepayDocNoInput(c)),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              _buildSectionHeader(
                c,
                icon: Icons.receipt_long_rounded,
                title: TransactionUiText.repayLoanRefLoanLabel,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(
                      span: columnCount >= 4 ? 2 : columnCount,
                      child: _buildRepayRefLoanFields(c),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              _buildSectionHeader(
                c,
                icon: Icons.account_balance_wallet_outlined,
                title: TransactionUiText.amountSection,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(child: _buildRepayAmountInput(c)),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              _buildSectionHeader(
                c,
                icon: Icons.notes_rounded,
                title: TransactionUiText.additionalDetails,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(
                      span: columnCount,
                      child: _buildRepayRemarkInput(c),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _cardContentWidth(double cardWidth) {
    final horizontalPadding = AppTheme.sp16 * 2;
    return cardWidth > horizontalPadding
        ? cardWidth - horizontalPadding
        : cardWidth;
  }

  int _responsiveColumnCount(double maxWidth) {
    if (maxWidth >= 1180) return 4;
    if (maxWidth >= 900) return 3;
    if (maxWidth >= 560) return 2;
    return 1;
  }

  Widget _responsiveFieldGrid(
    double maxWidth, {
    required int columnCount,
    required List<_ResponsiveFormField> fields,
    double spacing = AppTheme.sp12,
  }) {
    final columns = columnCount.clamp(1, 4).toInt();
    final columnWidth = (maxWidth - (spacing * (columns - 1))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: fields.map((field) {
        final span = field.span.clamp(1, columns).toInt();
        final width = (columnWidth * span) + (spacing * (span - 1));
        return SizedBox(
          width: width,
          child: field.child,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, __) {
        if (!didPop) _handleBackNavigation();
      },
      child: SafeArea(
        child: Scaffold(
          backgroundColor: c.background,
          appBar: _buildAppBar(c),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        icon: Icons.payments_outlined,
                        iconColor: c.loanAmber,
                        iconBgColor: c.iconBgLoan,
                        title: _isEditMode
                            ? TransactionUiText.repayLoanEditItem
                            : TransactionUiText.repayLoanAddItem,
                        subtitle: TransactionUiText.reviewBeforeSave,
                        quickHint:
                            TransactionUiText.repayLoanRequiredBeforeSaveHint,
                        hintAccentColor: c.loanAmber,
                        hintBorderColor: c.cardBorder,
                        textPrimaryColor: c.textPrimary,
                        showQuickHint: false,
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      _buildFormCard(c),
                      const SizedBox(height: AppTheme.sp16),
                      _buildSummaryActions(c),
                      const SizedBox(height: AppTheme.sp24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickGuide(AppColors c) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined, size: 18, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              TransactionUiText.repayLoanQuickGuideHint,
              style: _pageBodyStyle(c, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPageGuideDialog() async {
    final c = AppColors.of(context);
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.repayLoanPageGuideTitle,
      items: [
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.repayLoanRequiredBeforeSaveHint,
          accentColor: c.loanAmber,
          backgroundColor: c.iconBgLoan,
        ),
      ],
      children: [_buildQuickGuide(c)],
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: c.cardWhite,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: c.textPrimary,
        ),
        onPressed: _handleBackNavigation,
      ),
      title: widget.embeddedInHome
          ? const SizedBox.shrink()
          : Text(
              _isEditMode
                  ? TransactionUiText.repayLoanEditItem
                  : TransactionUiText.repayLoanAddItem,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
      actions: [
        Consumer<RepayLoanProvider>(
          builder: (_, p, __) {
            final isReady = _isFormReady();
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: AppTheme.sp12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.help_outline_rounded,
                      size: 20,
                      color: c.textSecondary,
                    ),
                    tooltip: TransactionUiText.repayLoanPageGuideTitle,
                    visualDensity: VisualDensity.compact,
                    onPressed: _showPageGuideDialog,
                  ),
                  if (!_isEditMode && _hasUnsavedChanges())
                    IconButton(
                      icon: Icon(
                        Icons.cleaning_services_outlined,
                        size: 18,
                        color: c.textSecondary,
                      ),
                      tooltip: TransactionUiText.formClearTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: _confirmAndResetForm,
                    ),
                  if (_isEditMode)
                    AppBarActionButton(
                      onPressed: _handleBackNavigation,
                      label: TransactionUiText.cancel,
                    ),
                  AppBarActionButton(
                    label: TransactionUiText.save,
                    onPressed: _onSave,
                    isEnabled: isReady,
                    isLoading: p.isLoading,
                    isPrimary: true,
                  ),
                ],
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildLoanStatusHint(AppColors c, String loanId) {
    final remain = _remainingByLoanId(
      loanId,
      excludeRepayId:
          _isEditMode ? widget.initialData!['id']?.toString() : null,
    );
    final row = _loanRowById(loanId);
    final borrower = row?['borrower']?.toString() ?? '-';
    final dueRaw = row?['duedate']?.toString() ?? '';
    final dueText = dueRaw.trim().isEmpty ? '-' : _formatDate(dueRaw);
    final isOverdue = _isLoanOverdueByLoanId(
      loanId,
      excludeRepayId:
          _isEditMode ? widget.initialData!['id']?.toString() : null,
    );
    final accent = isOverdue ? c.expenseRed : c.loanAmber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOverdue
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              isOverdue
                  ? TransactionUiText.repayLoanOverdueHint(
                      borrower: borrower,
                      dueDate: dueText,
                      remaining: remain.toStringAsFixed(2),
                    )
                  : TransactionUiText.repayLoanRemainingHint(
                      borrower: borrower,
                      dueDate: dueText,
                      remaining: remain.toStringAsFixed(2),
                    ),
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSave() async {
    final refLoan = _selectedLoanId;
    final amountText = _amountCtrl.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText) ?? 0;
    if (refLoan.isEmpty) {
      _showSnack(TransactionUiText.repayLoanSnackFillRef);
      return;
    }
    final loanProvider = _loanProviderOrNull;
    if (loanProvider == null) {
      _showSnack(TransactionUiText.providerNotFound);
      return;
    }
    if (loanProvider.rows.isNotEmpty && !_loanExists(refLoan)) {
      _showSnack(TransactionUiText.repayLoanSnackLoanNotFound);
      return;
    }
    if (amount <= 0) {
      _showSnack(TransactionUiText.amountMustPositive);
      return;
    }
    final loanAmount = _loanAmountById(refLoan);
    if (loanAmount > 0) {
      final remaining = _remainingByLoanId(
        refLoan,
        excludeRepayId:
            _isEditMode ? widget.initialData!['id']?.toString() : null,
      );
      if (remaining <= 0) {
        _showSnack(TransactionUiText.repayLoanSnackFullyRepaid);
        return;
      }
      if (amount > remaining) {
        _showSnack(
          TransactionUiText.repayLoanSnackExceedsRemaining(
            '${remaining.toStringAsFixed(2)} ${TransactionUiText.baht}',
          ),
        );
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (!mounted) return;
    final provider = context.read<RepayLoanProvider>();
    final success = _isEditMode
        ? await provider.updateRepayLoan(
            localId: widget.initialData!['id']?.toString() ?? '',
            token: token,
            docno: widget.initialData!['docno']?.toString() ?? '',
            refLoan: refLoan,
            amount: amount.toString(),
            remark: _remarkCtrl.text.trim(),
            duedate: _repayDate,
            created: widget.initialData!['created']?.toString() ??
                DateTime.now().toIso8601String(),
          )
        : await provider.saveRepayLoan(
            token: token,
            docno: _docnoCtrl.text.trim(),
            refLoan: refLoan,
            amount: amount.toString(),
            remark: _remarkCtrl.text.trim(),
            duedate: _repayDate,
          );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      return;
    }
    _showSnack(provider.error ?? TransactionUiText.saveFailedTitle);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            msg,
            style: const TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
  }

  String _formatDate(String raw) {
    return ThaiDateFormatter.format(raw, fallback: raw);
  }

  Future<void> _handleBackNavigation() async {
    if (_isHandlingBackNavigation) return;
    _isHandlingBackNavigation = true;
    FocusScope.of(context).unfocus();
    try {
      if (!_hasUnsavedChanges()) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      final shouldLeave = await showFormLeaveConfirmDialog(
        context,
        title: TransactionUiText.loanUnsavedLeaveTitle,
        message: TransactionUiText.loanUnsavedLeaveBody,
        cancelText: TransactionUiText.loanUnsavedStay,
        confirmText: TransactionUiText.loanUnsavedLeaveWithoutSave,
        confirmColor: AppColors.of(context).loanAmber,
      );
      if (shouldLeave && mounted) {
        Navigator.of(context).pop(false);
      }
    } finally {
      _isHandlingBackNavigation = false;
    }
  }

  Future<void> _confirmAndResetForm() async {
    FocusScope.of(context).unfocus();
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.loanResetTitle,
        message: TransactionUiText.loanResetBody,
        cancelText: TransactionUiText.loanResetCancel,
        confirmText: TransactionUiText.loanResetConfirm,
        confirmColor: AppColors.of(dialogContext).loanAmber,
      ),
    );
    if (shouldReset != true || !mounted) return;
    _refLoanCtrl.clear();
    _selectedLoanId = '';
    _amountCtrl.clear();
    _remarkCtrl.clear();
    final now = DateTime.now();
    setState(() {
      _selectedRepayDate = now;
      _repayDate = now.toIso8601String();
    });
    final provider = context.read<RepayLoanProvider>();
    final docno = await provider.fetchDocNo(
      tableName: 'repay_loan',
      docDate: now.toIso8601String().split('T').first,
    );
    if (!mounted) return;
    _docnoCtrl.text = docno ?? '';
    _captureInitialSnapshot();
    _showSnack(TransactionUiText.loanResetDone);
  }

  bool _isFormReady() {
    final refLoan = _selectedLoanId;
    final amount =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '')) ?? 0;
    if (refLoan.isEmpty || amount <= 0) return false;
    if (_hasLoanCatalog && !_loanExists(refLoan)) return false;
    final loanAmount = _loanAmountById(refLoan);
    if (loanAmount <= 0) return false;
    final remaining = _remainingByLoanId(
      refLoan,
      excludeRepayId:
          _isEditMode ? widget.initialData!['id']?.toString() : null,
    );
    return remaining > 0 && amount <= remaining;
  }

  String _buildMissingRequiredText() {
    final missing = <String>[];
    final refLoan = _selectedLoanId;
    final amount =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '')) ?? 0;
    if (refLoan.isEmpty) missing.add(TransactionUiText.repayLoanRefLoanLabel);
    if (amount <= 0) missing.add(TransactionUiText.amount);
    if (_hasLoanCatalog && refLoan.isNotEmpty && !_loanExists(refLoan)) {
      missing.add(TransactionUiText.repayLoanRefLoanLabel);
    }
    if (refLoan.isNotEmpty && _loanExists(refLoan)) {
      final remaining = _remainingByLoanId(
        refLoan,
        excludeRepayId:
            _isEditMode ? widget.initialData!['id']?.toString() : null,
      );
      if (remaining <= 0) {
        missing.add(TransactionUiText.repayLoanSnackFullyRepaid);
      }
      if (amount > 0 && remaining > 0 && amount > remaining) {
        missing.add(
          TransactionUiText.repayLoanSnackExceedsRemaining(
            '${remaining.toStringAsFixed(2)} ${TransactionUiText.baht}',
          ),
        );
      }
    }
    if (missing.isEmpty) return TransactionUiText.loanReadyToSave;
    return '${TransactionUiText.loanMissingRequiredPrefix}${missing.join(', ')}';
  }

  Widget _buildSaveReadinessHint(AppColors c, bool isReadyToSave) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: isReadyToSave ? c.iconBgLoan : c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(
          color:
              isReadyToSave ? c.loanAmber.withValues(alpha: 0.6) : c.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isReadyToSave
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: isReadyToSave ? c.loanAmber : c.textSecondary,
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              isReadyToSave
                  ? TransactionUiText.loanReadyToSave
                  : _buildMissingRequiredText(),
              style: _pageBodyStyle(
                c,
                fontSize: 13,
                height: 1.35,
                color: isReadyToSave ? c.loanAmber : c.textPrimary,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _pageBodyStyle(
    AppColors c, {
    required double fontSize,
    FontWeight? weight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? c.textPrimary,
      height: height,
      letterSpacing: 0.2,
    );
  }
}
