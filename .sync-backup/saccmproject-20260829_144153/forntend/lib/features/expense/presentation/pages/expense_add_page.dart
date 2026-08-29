// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/constants/money_type_pocket.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/expense_req_local_data_source.dart';
import 'package:saccm/features/approval/data/expense_entry_prefill_resolver.dart';
import 'package:saccm/features/expense/domain/models/expense_entry_prefill.dart';
import 'package:saccm/features/expense/domain/rules/cash_keeping_fund_rule.dart';
import 'package:saccm/features/expense/domain/rules/expense_budget_source_rule.dart';
import 'package:saccm/features/expense/presentation/providers/expense_provider.dart';
import 'package:saccm/features/budget_source/presentation/pages/budget_source_page.dart';
import 'package:saccm/features/expense/presentation/widgets/expense_pay_cheque_lines_editor.dart';
import 'package:saccm/features/income_type/presentation/pages/income_type_page.dart';
import 'package:saccm/features/income_type/presentation/providers/income_type_provider.dart';
import 'package:saccm/features/party/presentation/pages/party_management_page.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:saccm/widgets/dialog/form_leave_confirm_dialog.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// บรรทัดย่อยใบสำคัญคู่จ่าย (expense_sub) — หลายบรรทัดต่อ 1 ใบ
class _ExpenseLineCtrls {
  final TextEditingController amount = TextEditingController();
  final TextEditingController lineRemark = TextEditingController();

  void dispose() {
    amount.dispose();
    lineRemark.dispose();
  }
}

class ExpenseAddWidget extends StatelessWidget {
  const ExpenseAddWidget({
    super.key,
    required this.inputWidth,
    this.initialData,
    this.embeddedInHome = false,
  });
  final double inputWidth;
  final Map<String, dynamic>? initialData;
  final bool embeddedInHome;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: ExpenseAddData(
        inputWidth: inputWidth,
        initialData: initialData,
        embeddedInHome: embeddedInHome,
      ),
    );
  }
}

class ExpenseAddData extends StatefulWidget {
  const ExpenseAddData({
    super.key,
    required this.inputWidth,
    this.initialData,
    this.embeddedInHome = false,
  });
  final double inputWidth;
  final Map<String, dynamic>? initialData;
  final bool embeddedInHome;

  @override
  State<ExpenseAddData> createState() => _ExpenseAddDataState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _ExpenseAddDataState extends State<ExpenseAddData> {
  String? token;
  String? userId;
  final _docno = TextEditingController();
  final _payTo = TextEditingController();
  final _detail = TextEditingController();
  final _remark = TextEditingController();

  /// หลายบรรทัด expense_sub — บรรทัดแรกอย่างน้อย 1
  List<_ExpenseLineCtrls> _expenseLineRows = [];
  final _chequeLinesKey = GlobalKey<ExpensePayChequeLinesEditorState>();
  final FocusNode _docnoFocusNode = FocusNode();
  final FocusNode _payToFocusNode = FocusNode();
  final FocusNode _detailFocusNode = FocusNode();
  final FocusNode _remarkFocusNode = FocusNode();
  final _expenseReqDs =
      ServiceLocator.instance.get<ExpenseReqLocalDataSource>();
  final _expenseReqPrefillResolver = ExpenseEntryPrefillResolver();
  late String docDate = DateTime.now().toString();
  DateTime _selectedDocDate = DateTime.now();
  late ExpenseProvider expenseProvider;
  String _initialDocNo = '';
  String _initialPayTo = '';
  String _initialDetail = '';
  String _initialAmount = '';
  String _initialRemark = '';
  String _initialBudgetSourceCode = '';
  String _initialExpenseTypeCode = '';
  String _initialFundCategoryId = '';
  String _initialMoneyTypeCode = '';
  String _initialDocDate = '';
  String _initialSubLinesSnap = '';
  String _initialChequeLinesSnap = '';
  List<Map<String, dynamic>>? _initialPayChequeRows;
  bool _isHandlingBackNavigation = false;
  bool get _isEditMode => widget.initialData != null;
  Timer? _autoSaveDebounce;
  String? _autoDraftLocalId;
  String? _lastAutoDraftSignature;
  bool _isAutoSaving = false;
  String _autoDraftMessage = TransactionUiText.autoDraftWaiting;
  ExpenseEntryPrefill? _expenseReqPrefill;

  /// เลขที่เอกสาร — รอ fetchDocNo (provider ไม่ track — page เป็นคนเรียก)
  bool _isDocNoLoading = true;

  /// โหลด expense_type, budget_source, money_type, หมวด OB พร้อมกัน
  bool _isExpenseSectionLoading = true;

  Future<void> _checkSetupReadiness() async {
    await _loadReceiverPartyRows(forceRefresh: false);
  }

  /// ลดการยิงซ้ำ — แคช in-memory รายชื่อผู้รับ (ข้อมูลมาจาก SQLite เสมอ)
  List<Map<String, dynamic>>? _receiverRowsCache;
  DateTime? _receiverRowsCacheAt;
  static const _receiverRowsCacheTtl = Duration(minutes: 2);
  Future<List<Map<String, dynamic>>>? _receiverRowsInflight;
  int _receiverLoadGeneration = 0;

  void _invalidateReceiverRowsCache() {
    _receiverLoadGeneration++;
    _receiverRowsCache = null;
    _receiverRowsCacheAt = null;
  }

  static List<Map<String, dynamic>> _filterReceiverRowsActive(
    List<Map<String, dynamic>> raw,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final row in raw) {
      if (!_partyRowIsActive(row) || !_partyRowCanActAsReceiver(row)) continue;
      out.add(row);
    }
    return out;
  }

  void _warmReceiverPartyCacheInBackground() {
    unawaited(
      _loadReceiverPartyRows(forceRefresh: false).catchError(
        (_, __) => <Map<String, dynamic>>[],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final first = _ExpenseLineCtrls();
    first.amount.addListener(_onAnyFieldChanged);
    first.lineRemark.addListener(_onAnyFieldChanged);
    _expenseLineRows = [first];
    _detail.addListener(_onAnyFieldChanged);
    _payTo.addListener(_onAnyFieldChanged);
    _docno.addListener(_onAnyFieldChanged);
    _remark.addListener(_onAnyFieldChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) => _loadPage());
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _detail.removeListener(_onAnyFieldChanged);
    _payTo.removeListener(_onAnyFieldChanged);
    _docno.removeListener(_onAnyFieldChanged);
    _remark.removeListener(_onAnyFieldChanged);
    for (final r in _expenseLineRows) {
      r.amount.removeListener(_onAnyFieldChanged);
      r.lineRemark.removeListener(_onAnyFieldChanged);
      r.dispose();
    }
    _docno.dispose();
    _payTo.dispose();
    _detail.dispose();
    _remark.dispose();
    _docnoFocusNode.dispose();
    _detailFocusNode.dispose();
    _payToFocusNode.dispose();
    _remarkFocusNode.dispose();
    super.dispose();
  }

  void _disposeExpenseLineRowsOnly() {
    for (final r in _expenseLineRows) {
      r.amount.removeListener(_onAnyFieldChanged);
      r.lineRemark.removeListener(_onAnyFieldChanged);
      r.dispose();
    }
    _expenseLineRows = [];
  }

  void _resetExpenseLinesToSingleEmpty() {
    _disposeExpenseLineRowsOnly();
    final first = _ExpenseLineCtrls();
    first.amount.addListener(_onAnyFieldChanged);
    first.lineRemark.addListener(_onAnyFieldChanged);
    _expenseLineRows = [first];
  }

  void _addExpenseLine() {
    final c = _ExpenseLineCtrls();
    c.amount.addListener(_onAnyFieldChanged);
    c.lineRemark.addListener(_onAnyFieldChanged);
    setState(() => _expenseLineRows.add(c));
    _scheduleAutoSave();
  }

  void _removeExpenseLineAt(int index) {
    if (index <= 0 || index >= _expenseLineRows.length) return;
    setState(() {
      final r = _expenseLineRows.removeAt(index);
      r.amount.removeListener(_onAnyFieldChanged);
      r.lineRemark.removeListener(_onAnyFieldChanged);
      r.dispose();
    });
    _scheduleAutoSave();
  }

  /// โหลด expense_sub + pay_cheque ลงฟอร์ม (โหมดแก้ไข)
  void _applyExpenseLinesFromSubs(
    List<Map<String, dynamic>> subs,
    Map<String, dynamic> header,
  ) {
    _disposeExpenseLineRowsOnly();
    if (subs.isEmpty) {
      final first = _ExpenseLineCtrls();
      first.amount.text =
          _normalizeAmountText(header['amount']?.toString() ?? '');
      first.amount.addListener(_onAnyFieldChanged);
      first.lineRemark.addListener(_onAnyFieldChanged);
      _expenseLineRows = [first];
      return;
    }
    final rows = <_ExpenseLineCtrls>[];
    for (final s in subs) {
      final c = _ExpenseLineCtrls();
      c.amount.text = _normalizeAmountText(s['amount']?.toString() ?? '');
      c.lineRemark.text = s['remark']?.toString() ?? '';
      c.amount.addListener(_onAnyFieldChanged);
      c.lineRemark.addListener(_onAnyFieldChanged);
      rows.add(c);
    }
    _expenseLineRows = rows;
  }

  double _sumLineAmounts() {
    var t = 0.0;
    for (final r in _expenseLineRows) {
      t += _parseAmount(r.amount.text);
    }
    return t;
  }

  double _parseAmount(String raw) =>
      double.tryParse(raw.replaceAll(',', '').trim()) ?? 0;

  String _normalizeAmountText(String raw) {
    final v = _parseAmount(raw);
    if (v == 0 && raw.replaceAll(',', '').trim().isEmpty) return '';
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }

  String _totalAmountString() {
    final v = _sumLineAmounts();
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }

  String _subLinesSnapshot() {
    final parts = <String>[];
    for (final r in _expenseLineRows) {
      parts.add(
          '${_normalizeAmountText(r.amount.text)}|${r.lineRemark.text.trim()}');
    }
    return parts.join(';;');
  }

  List<Map<String, dynamic>> _buildSubDataPayload(ExpenseProvider p) {
    final off = _budgetSourceIsOffBudget(p);
    final out = <Map<String, dynamic>>[];
    for (final line in _expenseLineRows) {
      final amt = _normalizeAmountText(line.amount.text);
      final rmk = line.lineRemark.text.trim().isNotEmpty
          ? line.lineRemark.text
          : _remark.text;
      out.add(<String, dynamic>{
        'amount': amt,
        'remark': rmk,
        'refexpensetype': p.expenseTypeCode.isEmpty ? null : p.expenseTypeCode,
        'refmoneytype': p.moneyTypeCode.isEmpty ? null : p.moneyTypeCode,
        if (off && p.fundCategoryId.isNotEmpty)
          'refincometype': p.fundCategoryId,
      });
    }
    return out;
  }

  String? _moneyDomainForSave(ExpenseProvider p) {
    final mc = _selectedBudgetMasterCode(p);
    if (mc == 'GOV') return 'budget';
    if (mc != null) return 'off_budget';
    return null;
  }

  Future<String?> _promptEditReason() async {
    final c = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: AdaptiveContentSheet(
            title: TransactionUiText.expenseEditReasonTitle,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                MediaQuery.viewInsetsOf(sheetContext).bottom + AppTheme.sp16,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppInput(
                      label: TransactionUiText.expenseEditReasonHint,
                      controller: c,
                      maxLines: 3,
                      minLines: 2,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text(
                            TransactionUiText.expenseEditReasonCancel,
                            style: TextStyle(fontFamily: _fontFamily),
                          ),
                        ),
                        const SizedBox(width: AppTheme.sp8),
                        AppButton.primary(
                          label: TransactionUiText.expenseEditReasonConfirm,
                          fullWidth: false,
                          onPressed: () =>
                              Navigator.pop(sheetContext, c.text.trim()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    c.dispose();
    if (reason == null) return null;
    if (reason.trim().isEmpty) {
      _showSnack(TransactionUiText.expenseEditReasonRequired);
      return null;
    }
    return reason.trim();
  }

  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

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

  @override
  Widget build(BuildContext context) {
    expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

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
                        icon: Icons.north_rounded,
                        iconColor: scheme.primary,
                        iconBgColor: c.iconBgExpense,
                        title: TransactionUiText.expenseItemInfo,
                        subtitle: TransactionUiText.reviewBeforeSave,
                        quickHint:
                            TransactionUiText.expenseRequiredBeforeSaveHint,
                        hintAccentColor: scheme.primary,
                        hintBorderColor: c.cardBorder,
                        textPrimaryColor: c.textPrimary,
                        showQuickHint: false,
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      _buildFormCard(c),
                      const SizedBox(height: AppTheme.sp16),
                      _buildActionRow(c),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 18, color: accent),
              const SizedBox(width: AppTheme.sp8),
              Text(
                TransactionUiText.expenseQuickGuideTitle,
                style: TextStyle(
                  color: c.textPrimary,
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp8),
          Wrap(
            spacing: AppTheme.sp8,
            runSpacing: AppTheme.sp8,
            children: [
              _quickGuideChip(
                c,
                TransactionUiText.expenseQuickGuideStepType,
                Icons.category_outlined,
              ),
              _quickGuideChip(
                c,
                TransactionUiText.expenseQuickGuideStepBudget,
                Icons.account_tree_outlined,
              ),
              _quickGuideChip(
                c,
                TransactionUiText.expenseQuickGuideStepPayment,
                Icons.payments_outlined,
              ),
              _quickGuideChip(
                c,
                TransactionUiText.expenseQuickGuideStepOb,
                Icons.book_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp8),
          Text(
            TransactionUiText.expenseQuickGuideHint,
            style: _pageBodyStyle(c, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Future<void> _showPageGuideDialog() async {
    final c = AppColors.of(context);
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.expensePageGuideTitle,
      items: [
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.expenseRequiredBeforeSaveHint,
          backgroundColor: c.iconBgExpense,
        ),
      ],
      children: [_buildQuickGuide(c)],
    );
  }

  Future<List<AppDropdownItem<String>>> _loadExpenseReqLookupItems() async {
    final rows = await _expenseReqDs.getApprovedReadyForExpenseEntry();
    return rows.map((item) {
      final amount =
          double.tryParse(item.amount.replaceAll(',', '').trim()) ?? 0;
      final amountText = NumberFormat('#,##0.00').format(amount);
      return AppDropdownItem<String>(
        value: item.id,
        label: '${item.docno} - ${item.memberLabel}',
        subtitle: '$amountText ${TransactionUiText.baht}',
      );
    }).toList();
  }

  Future<void> _openExpenseReqPickerFromAppBar() async {
    if (_isEditMode || _isExpenseSectionLoading) return;
    FocusScope.of(context).unfocus();
    final c = AppColors.of(context);
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.cardWhite,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (_) => _ExpenseReqPickerSheet(
        loadItems: _loadExpenseReqLookupItems,
        selectedValue: _expenseReqPrefill?.expenseReqId,
      ),
    );
    if (!mounted || selectedId == null) return;
    await _selectExpenseReq(selectedId);
  }

  Future<void> _selectExpenseReq(String? id) async {
    final selectedId = id?.trim() ?? '';
    if (selectedId.isEmpty) return;
    final prefill =
        await _expenseReqPrefillResolver.resolve({'id': selectedId});
    if (!mounted) return;
    if (prefill == null) {
      showAutoDismissAlert(
        context,
        TransactionUiText.warning,
        TransactionUiText.expenseEntryPrefillResolveFailed,
        3,
      );
      return;
    }
    await _applyExpenseReqPrefill(prefill);
  }

  Future<void> _applyExpenseReqPrefill(ExpenseEntryPrefill prefill) async {
    final p = context.read<ExpenseProvider>();
    p.applyEntryPrefill(prefill);

    _disposeExpenseLineRowsOnly();
    final first = _ExpenseLineCtrls();
    first.amount.text = _normalizeAmountText(prefill.amount);
    first.amount.addListener(_onAnyFieldChanged);
    first.lineRemark.addListener(_onAnyFieldChanged);
    _expenseLineRows = [first];

    _payTo.text = prefill.payToName;
    _detail.text = prefill.detail;
    final ref = prefill.referenceNote;
    final remark = prefill.remark?.trim() ?? '';
    _remark.text = remark.isNotEmpty ? '$remark\n$ref' : ref;
    _initialPayChequeRows = null;
    p.addChequeAccountId('');

    setState(() => _expenseReqPrefill = prefill);
    _scheduleAutoSave();
  }

  Widget _quickGuideChip(AppColors c, String text, IconData icon) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: c.textPrimary,
              fontFamily: _fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: c.cardWhite,
      actions: [
        Consumer<ExpenseProvider>(
          builder: (_, p, __) {
            final isReady = _isFormReady(p);
            final compactActions = MediaQuery.sizeOf(context).width < 520;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: AppTheme.sp12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.help_outline_rounded,
                        size: 20, color: c.textSecondary),
                    tooltip: TransactionUiText.expensePageGuideTitle,
                    visualDensity: VisualDensity.compact,
                    onPressed: _showPageGuideDialog,
                  ),
                  if (!_isEditMode)
                    compactActions
                        ? IconButton(
                            icon: Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 20,
                              color: _isExpenseSectionLoading
                                  ? c.textHint
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            tooltip: TransactionUiText
                                .expenseReqReferencePickerTitle,
                            visualDensity: VisualDensity.compact,
                            onPressed: _isExpenseSectionLoading
                                ? null
                                : _openExpenseReqPickerFromAppBar,
                          )
                        : AppBarActionButton(
                            label: TransactionUiText
                                .expenseReqReferencePickerTitle,
                            onPressed: _openExpenseReqPickerFromAppBar,
                            isEnabled: !_isExpenseSectionLoading,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.sp12,
                            ),
                          ),
                  if (!_isEditMode && _hasUnsavedChanges())
                    IconButton(
                      icon: Icon(Icons.cleaning_services_outlined,
                          size: 18, color: c.textSecondary),
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
                    onPressed: _saveOnPressed,
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
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: c.textPrimary),
        onPressed: _handleBackNavigation,
      ),
      title: widget.embeddedInHome
          ? const SizedBox.shrink()
          : Text(
              _isEditMode
                  ? TransactionUiText.editExpenseItem
                  : TransactionUiText.addExpenseItem,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
      centerTitle: true,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
      ),
    );
  }

  Widget _buildFormCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final contentWidth = _cardContentWidth(box.maxWidth);
          final columnCount = _responsiveColumnCount(contentWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(c,
                  icon: Icons.description_outlined,
                  title: TransactionUiText.documentInfo),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.sp16, 0, AppTheme.sp16, AppTheme.sp16),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(
                      child: AppDateInput(
                        initialValue: _selectedDocDate,
                        label: TransactionUiText.date,
                        dateFormat: AppDateFormat.thaiBuddhist,
                        onChanged: (d) {
                          if (d != null) {
                            _selectedDocDate = d;
                            docDate = d.toString();
                            if (!_isEditMode) _refreshDocNoForSelectedDate();
                            _scheduleAutoSave();
                          }
                        },
                      ),
                    ),
                    _ResponsiveFormField(
                      child: _isDocNoLoading
                          ? _skeletonField(width: null)
                          : AppInput(
                              label: TransactionUiText.docNumber,
                              hint: TransactionUiText.autoGenerated,
                              helperText: TransactionUiText.docNoAutoHelper,
                              readOnly: true,
                              focusNode: _docnoFocusNode,
                              controller: _docno,
                              prefixIcon: const Icon(Icons.tag_rounded),
                            ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              _buildSectionHeader(c,
                  icon: Icons.account_balance_wallet_outlined,
                  title: TransactionUiText.expenseAccountingSectionTitle),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.sp16, 0, AppTheme.sp16, AppTheme.sp16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountingStepLabel(
                      c,
                      TransactionUiText.expenseAccountingStep1Label,
                      isFirst: true,
                    ),
                    _responsiveFieldGrid(
                      contentWidth,
                      columnCount: columnCount,
                      fields: [
                        _ResponsiveFormField(
                          child: Consumer<ExpenseProvider>(
                            builder: (_, p, __) => _isExpenseSectionLoading
                                ? _skeletonField(width: null)
                                : AppLookupPickerField<String>(
                                    label: TransactionUiText.expenseTypeTitle,
                                    required: true,
                                    helperText:
                                        TransactionUiText.expenseTypeHelperText,
                                    clearable: false,
                                    items: p.expenseTypes
                                        .map((e) => AppDropdownItem<String>(
                                            value: e[0], label: e[1]))
                                        .toList(),
                                    value: p.expenseTypeCode.isEmpty
                                        ? null
                                        : p.expenseTypeCode,
                                    onChanged: (v) =>
                                        _onExpenseTypeChanged(p, v ?? ''),
                                  ),
                          ),
                        ),
                        _ResponsiveFormField(
                          span: columnCount >= 4 ? 2 : 1,
                          child: Consumer<ExpenseProvider>(
                            builder: (_, p, __) =>
                                _buildBudgetSourceSelector(c, p),
                          ),
                        ),
                      ],
                    ),
                    Consumer<ExpenseProvider>(
                      builder: (_, p, __) {
                        if (_isExpenseSectionLoading) {
                          return const SizedBox.shrink();
                        }
                        final off = _budgetSourceIsOffBudget(p);
                        if (!off) return const SizedBox.shrink();
                        final hasBudget = p.budgetSourceCode.isNotEmpty;
                        final items = p.offBudgetFundCategories;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAccountingStepLabel(
                              c,
                              TransactionUiText.expenseAccountingStep2Label,
                            ),
                            _responsiveFieldGrid(
                              contentWidth,
                              columnCount: columnCount,
                              fields: [
                                _ResponsiveFormField(
                                  span: columnCount >= 4 ? 2 : 1,
                                  child: _buildOffBudgetFundCategoryField(
                                    hasBudget: hasBudget,
                                    items: items,
                                    provider: p,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    _buildAccountingStepLabel(
                      c,
                      TransactionUiText.expenseAccountingStep3Label,
                    ),
                    _buildPaymentAndAmountFields(
                      c,
                      contentWidth: contentWidth,
                      columnCount: columnCount,
                    ),
                    Consumer<ExpenseProvider>(
                      builder: (_, p, __) {
                        if (_isExpenseSectionLoading) {
                          return const SizedBox.shrink();
                        }
                        if (!_isPayingByCheque(p)) {
                          return const SizedBox.shrink();
                        }
                        return _buildChequeSection(c, p);
                      },
                    ),
                    Consumer<ExpenseProvider>(
                      builder: (_, p, __) {
                        if (_isExpenseSectionLoading) {
                          return const SizedBox.shrink();
                        }
                        final hint = _buildKeepLimitHint(p);
                        if (hint == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppTheme.sp12),
                          child: _buildKeepLimitBanner(c, hint),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              _buildSectionHeader(c,
                  icon: Icons.notes_rounded,
                  title: TransactionUiText.additionalDetails),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.sp16, 0, AppTheme.sp16, AppTheme.sp16),
                child: _responsiveFieldGrid(
                  contentWidth,
                  columnCount: columnCount,
                  fields: [
                    _ResponsiveFormField(
                      span: columnCount >= 4 ? 2 : 1,
                      child: _buildPayToField(c),
                    ),
                    _ResponsiveFormField(
                      span: columnCount >= 4 ? 2 : 1,
                      child: AppInput(
                        label: TransactionUiText.detail,
                        hint: TransactionUiText.expenseDetailHint,
                        required: true,
                        helperText:
                            TransactionUiText.expenseDetailRequiredHelper,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _remarkFocusNode.requestFocus(),
                        focusNode: _detailFocusNode,
                        controller: _detail,
                        maxLines: 2,
                        minLines: 2,
                        prefixIcon: const Icon(Icons.short_text_rounded),
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount,
                      child: AppInput(
                        label: TransactionUiText.remark,
                        hint: TransactionUiText.remarkHint,
                        minLines: 2,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        focusNode: _remarkFocusNode,
                        controller: _remark,
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                      ),
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

  Widget _buildBudgetSourceSelector(AppColors c, ExpenseProvider p) {
    if (_isExpenseSectionLoading) return _skeletonField(width: null);

    final scheme = Theme.of(context).colorScheme;
    final hasExpenseType = p.expenseTypeCode.isNotEmpty;
    final noBudgetSourceForType = hasExpenseType && p.budgetSource.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppLookupPickerField<String>(
          label: TransactionUiText.budgetSourceTitle,
          required: true,
          enabled: hasExpenseType && !noBudgetSourceForType,
          hint: hasExpenseType
              ? (noBudgetSourceForType
                  ? TransactionUiText.expenseNoBudgetSourceForTypeHint
                  : null)
              : TransactionUiText.expenseChooseTypeFirstHint,
          hintStyle: noBudgetSourceForType
              ? TextStyle(
                  color: scheme.error,
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w600,
                )
              : null,
          helperText: hasExpenseType
              ? (noBudgetSourceForType
                  ? TransactionUiText.expenseNoBudgetSourceForTypeHelper
                  : TransactionUiText.expenseBudgetSourceFilteredHelper)
              : TransactionUiText.expenseBudgetSourceSelectLockedHelper,
          helperStyle: noBudgetSourceForType
              ? TextStyle(
                  color: scheme.error,
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w600,
                )
              : null,
          items: hasExpenseType
              ? p.budgetSource
                  .map((e) => AppDropdownItem<String>(value: e[0], label: e[1]))
                  .toList()
              : const [],
          value: hasExpenseType && p.budgetSourceCode.isNotEmpty
              ? p.budgetSourceCode
              : null,
          clearable: false,
          onChanged: hasExpenseType && !noBudgetSourceForType
              ? (v) => _onBudgetSourceChanged(p, v)
              : null,
        ),
        if (hasExpenseType && !noBudgetSourceForType) ...[
          const SizedBox(height: AppTheme.sp8),
          _buildBudgetFilterBanner(context, c, p),
        ],
        if (noBudgetSourceForType) ...[
          const SizedBox(height: AppTheme.sp8),
          TextButton.icon(
            onPressed: _openBudgetSourcePage,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(TransactionUiText.goManageBudgetSource),
          ),
        ],
      ],
    );
  }

  Widget _buildOffBudgetFundCategoryField({
    required bool hasBudget,
    required List<List<String>> items,
    required ExpenseProvider provider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppLookupPickerField<String>(
          label: TransactionUiText.expenseFundCategoryTitle,
          required: true,
          enabled: hasBudget && items.isNotEmpty,
          hint: !hasBudget
              ? TransactionUiText.expenseFundCategoryChooseFirst
              : (items.isEmpty
                  ? TransactionUiText.expenseNoObCategoriesHint
                  : null),
          helperText: TransactionUiText.expenseFundCategoryHelper,
          items: items
              .map((e) => AppDropdownItem<String>(
                    value: e[0],
                    label: e[1],
                  ))
              .toList(),
          value:
              provider.fundCategoryId.isEmpty ? null : provider.fundCategoryId,
          clearable: false,
          onChanged: hasBudget && items.isNotEmpty
              ? (v) {
                  provider.addFundCategoryId(v ?? '');
                  _scheduleAutoSave();
                }
              : null,
        ),
        if (items.isEmpty && hasBudget) ...[
          const SizedBox(height: AppTheme.sp8),
          TextButton.icon(
            onPressed: () => _openIncomeTypeManagement(),
            icon: const Icon(Icons.category_outlined, size: 16),
            label: const Text(TransactionUiText.goManageIncomeTypesOb),
          ),
        ],
      ],
    );
  }

  Widget _buildPayToField(AppColors c) {
    return ListenableBuilder(
      listenable: _payTo,
      builder: (context, _) {
        final selectedPayee = _payTo.text.trim();
        return AppLookupPickerField<String>(
          label: TransactionUiText.payTo,
          hint: TransactionUiText.payToHint,
          helperText: TransactionUiText.payToHelperRegisteredOnly,
          required: true,
          value: selectedPayee.isEmpty ? null : selectedPayee,
          displayLabel: selectedPayee.isEmpty ? null : selectedPayee,
          clearable: false,
          pickerTitle: TransactionUiText.expensePayeePickerTitle,
          searchHint: TransactionUiText.expensePayeePickerSearchHint,
          loadingText: TransactionUiText.expensePayeePickerLoading,
          emptyText: TransactionUiText.payToNoReceiverDialogBody,
          emptyActionLabel: TransactionUiText.receiveFromGoAddParty,
          onEmptyAction: _openPartyManagementPage,
          loadItems: _loadPayeeLookupItems,
          onChanged: (v) {
            final selectedName = v?.trim() ?? '';
            if (selectedName.isEmpty) return;
            setState(() => _payTo.text = selectedName);
            _detailFocusNode.requestFocus();
          },
          prefixIcon: const Icon(Icons.person_outline_rounded),
        );
      },
    );
  }

  Future<List<AppDropdownItem<String>>> _loadPayeeLookupItems() async {
    final rows = await _loadReceiverPartyRows();
    return rows.map((row) {
      final role = (row['role'] ?? 'both').toString().toLowerCase();
      final name = (row['name'] ?? '').toString();
      return AppDropdownItem<String>(
        value: name,
        label: name,
        subtitle: role == 'both'
            ? TransactionUiText.expensePayeeRoleBoth
            : TransactionUiText.expensePayeeRolePayee,
      );
    }).toList();
  }

  Widget _buildActionRow(AppColors c) {
    final amount = _sumLineAmounts();
    return Consumer<ExpenseProvider>(
      builder: (_, p, __) {
        final isReadyToSave = _isFormReady(p);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSaveReadinessHint(c, p, isReadyToSave),
            const SizedBox(height: AppTheme.sp8),
            TransactionSummaryActions(
              totalAmount: amount,
              totalLabel: TransactionUiText.totalAmount,
              amountColor: c.expenseRed,
              cardColor: c.cardWhite,
              borderColor: c.cardBorder,
              textSecondaryColor: c.textSecondary,
              currencyLabel: TransactionUiText.baht,
              saveLabel: TransactionUiText.save,
              isSaving: p.isLoading,
              onSave: _saveOnPressed,
              isSaveEnabled: isReadyToSave,
              saveDisabledHint:
                  isReadyToSave ? null : _buildMissingRequiredText(p),
              isEditMode: _isEditMode,
              cancelLabel: TransactionUiText.cancel,
              onCancel: _handleBackNavigation,
              showSaveButton: false,
            ),
            const SizedBox(height: AppTheme.sp8),
            _buildAutoDraftStatus(c),
          ],
        );
      },
    );
  }

  Widget _buildSaveReadinessHint(
      AppColors c, ExpenseProvider p, bool isReadyToSave) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp12, vertical: AppTheme.sp8),
      decoration: BoxDecoration(
        color: isReadyToSave ? c.iconBgExpense : c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(
          color: isReadyToSave
              ? c.expenseRed.withValues(alpha: 0.6)
              : c.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isReadyToSave
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: isReadyToSave ? c.expenseRed : c.textSecondary,
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              isReadyToSave
                  ? TransactionUiText.expenseReadyToSave
                  : _buildMissingRequiredText(p),
              style: _pageBodyStyle(
                c,
                fontSize: 13,
                height: 1.35,
                color: isReadyToSave ? c.expenseRed : c.textPrimary,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDraftStatus(AppColors c) {
    if (_isEditMode) return const SizedBox.shrink();
    final color = _autoDraftMessage == TransactionUiText.autoDraftFailed
        ? Theme.of(context).colorScheme.error
        : (_isAutoSaving ? c.expenseRed : c.textSecondary);
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: _isAutoSaving
              ? CircularProgressIndicator(strokeWidth: 2, color: color)
              : Icon(Icons.cloud_done_outlined, size: 16, color: color),
        ),
        const SizedBox(width: AppTheme.sp8),
        Expanded(
          child: Text(
            _autoDraftMessage,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(AppColors c,
      {required IconData icon, required String title}) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.sp16, AppTheme.sp16, AppTheme.sp16, AppTheme.sp12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Text(
            title,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAndAmountFields(
    AppColors c, {
    required double contentWidth,
    required int columnCount,
  }) {
    final firstAmountField = _buildExpenseAmountField(
      index: 0,
      label: TransactionUiText.expensePrimaryAmountLabel,
      helperText: TransactionUiText.expenseMultiLineAmountHelper,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _responsiveFieldGrid(
          contentWidth,
          columnCount: columnCount,
          fields: [
            _ResponsiveFormField(
              child: Consumer<ExpenseProvider>(
                builder: (_, p, __) => _isExpenseSectionLoading
                    ? _skeletonField(width: null)
                    : AppLookupPickerField<String>(
                        label: TransactionUiText.expenseMoneyChannelTitle,
                        required: true,
                        helperText: TransactionUiText.expenseMoneyChannelHelper,
                        clearable: false,
                        items: p.moneyTypes
                            .map((e) => AppDropdownItem<String>(
                                  value: e[0],
                                  label: e[1],
                                ))
                            .toList(),
                        value: p.moneyTypeCode.isEmpty ? null : p.moneyTypeCode,
                        onChanged: (v) => _onMoneyTypeChanged(p, v),
                      ),
              ),
            ),
            _ResponsiveFormField(child: firstAmountField),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        _responsiveFieldGrid(
          contentWidth,
          columnCount: columnCount,
          fields: [
            _ResponsiveFormField(
              span: columnCount,
              child: _buildLineRemarkField(index: 0),
            ),
          ],
        ),
        if (_expenseLineRows.length > 1) ...[
          const SizedBox(height: AppTheme.sp12),
          Text(
            TransactionUiText.expenseSplitLinesTitle,
            style: TextStyle(
              color: c.textSecondary,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppTheme.sp8),
          ...List.generate(
            _expenseLineRows.length - 1,
            (offset) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sp8),
              child: _buildSplitLineFields(
                c,
                offset + 1,
                contentWidth: contentWidth,
                columnCount: columnCount,
              ),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addExpenseLine,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text(
              TransactionUiText.expenseAddSubLine,
              style: const TextStyle(fontFamily: _fontFamily),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitLineFields(
    AppColors c,
    int index, {
    required double contentWidth,
    required int columnCount,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.call_split_outlined, size: 18, color: c.navy),
            const SizedBox(width: AppTheme.sp8),
            Expanded(
              child: Text(
                TransactionUiText.expenseSplitLineTitle(index + 1),
                style: TextStyle(
                  color: c.textPrimary,
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              tooltip: TransactionUiText.expenseRemoveSubLineTooltip,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, color: scheme.error),
              onPressed: () => _removeExpenseLineAt(index),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        _responsiveFieldGrid(
          contentWidth,
          columnCount: columnCount,
          fields: [
            _ResponsiveFormField(
              child: _buildExpenseAmountField(
                index: index,
                label: TransactionUiText.expenseLineAmountLabel(index + 1),
              ),
            ),
            _ResponsiveFormField(
              span: columnCount >= 4 ? 2 : 1,
              child: _buildLineRemarkField(index: index),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpenseAmountField({
    required int index,
    required String label,
    String? helperText,
  }) {
    return AppInput(
      label: label,
      hint: '0.00',
      required: true,
      helperText: helperText,
      action: const AppInputAction.number(allowDecimal: true),
      controller: _expenseLineRows[index].amount,
      textAlign: TextAlign.right,
      prefixIcon: const Icon(Icons.attach_money_rounded),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (p0) {
        if (p0 == null || p0.isEmpty) return TransactionUiText.fillAmount;
        if ((double.tryParse(p0.replaceAll(',', '')) ?? 0) <= 0) {
          return TransactionUiText.amountMustPositive;
        }
        return null;
      },
    );
  }

  Widget _buildLineRemarkField({
    required int index,
  }) {
    return AppInput(
      label: TransactionUiText.expenseLineRemarkLabel,
      hint: TransactionUiText.expenseLineRemarkHint,
      controller: _expenseLineRows[index].lineRemark,
      maxLines: 2,
      minLines: 1,
      prefixIcon: const Icon(Icons.notes_outlined, size: 20),
    );
  }

  /// Section เก็บข้อมูลเช็คเมื่อ moneyType เป็น "เช็ค" — ใช้บันทึกในทะเบียนคุมจ่ายเช็ค
  Widget _buildChequeSection(
    AppColors c,
    ExpenseProvider p,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAccountingStepLabel(c, TransactionUiText.expenseChequeStepLabel),
        ExpensePayChequeLinesEditor(
          key: _chequeLinesKey,
          provider: p,
          expenseTotal: _sumLineAmounts(),
          initialRows: _initialPayChequeRows,
          onChanged: _onAnyFieldChanged,
        ),
      ],
    );
  }

  Widget _buildAccountingStepLabel(AppColors c, String text,
      {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : AppTheme.sp12,
        bottom: AppTheme.sp8,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: c.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildBudgetFilterBanner(
    BuildContext context,
    AppColors c,
    ExpenseProvider p,
  ) {
    final accent = Theme.of(context).colorScheme.primary;
    final text = TransactionUiText.expenseBudgetFilterBannerGov;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.filter_alt_outlined, size: 16, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              text,
              style: _pageBodyStyle(c, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner แสดงวงเงินเก็บรักษา (cash_keeping_limit)
  /// เป็นเพียงข้อความเตือน — ไม่บล็อกการบันทึก
  Widget _buildKeepLimitBanner(AppColors c, String hint) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.tertiary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.savings_outlined, size: 16, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              hint,
              style: _pageBodyStyle(c, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Skeleton helpers ─────────────────────────────────────────────

  /// กล่อง skeleton สีเดียวกับ border — ใช้แทน field ขณะโหลด
  Widget _skeletonBox({double? width, double height = 48, double radius = 12}) {
    final c = AppColors.of(context);
    return _AnimatedSkeleton(
      width: width ?? double.infinity,
      height: height,
      radius: radius,
      baseColor: c.cardBorder.withValues(alpha: 0.5),
      highlightColor: c.cardWhite,
    );
  }

  /// skeleton label + field (เลียนแบบ AppInput/AppDropdownField)
  Widget _skeletonField({double? width, double fieldHeight = 48}) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _skeletonBox(width: 80, height: 14, radius: 6),
        const SizedBox(height: 6),
        _skeletonBox(width: width, height: fieldHeight),
      ],
    );
    return width != null ? SizedBox(width: width, child: child) : child;
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

  bool _canAutoSaveDraft(ExpenseProvider p) {
    return !_isEditMode &&
        (token?.isNotEmpty ?? false) &&
        (userId?.isNotEmpty ?? false) &&
        _docno.text.trim().isNotEmpty &&
        _hasAutoDraftMinimumInput(p);
  }

  bool _hasAutoDraftMinimumInput(ExpenseProvider p) {
    final offReady = !_budgetSourceIsOffBudget(p) ||
        (p.fundCategoryId.isNotEmpty && p.offBudgetFundCategories.isNotEmpty);
    final chequeReady = !_isPayingByCheque(p) ||
        _chequeLinesKey.currentState?.validate() == null;
    final hasAccounting = p.expenseTypeCode.isNotEmpty &&
        p.budgetSourceCode.isNotEmpty &&
        p.moneyTypeCode.isNotEmpty &&
        offReady &&
        chequeReady;
    final hasAmount = _sumLineAmounts() > 0;
    return hasAccounting && hasAmount;
  }

  String _buildAutoDraftSignature(ExpenseProvider p) {
    return [
      _docno.text.trim(),
      docDate,
      p.expenseTypeCode,
      p.budgetSourceCode,
      p.fundCategoryId,
      p.moneyTypeCode,
      _expenseReqPrefill?.expenseReqId ?? '',
      _payTo.text.trim(),
      _detail.text.trim(),
      _remark.text.trim(),
      _subLinesSnapshot(),
      _chequeLinesKey.currentState?.snapshot() ?? '',
    ].join('|');
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    if (!mounted) return;
    final p = context.read<ExpenseProvider>();
    if (!_canAutoSaveDraft(p)) {
      if (_autoDraftMessage != TransactionUiText.autoDraftWaiting) {
        setState(() => _autoDraftMessage = TransactionUiText.autoDraftWaiting);
      }
      return;
    }
    _autoSaveDebounce = Timer(
      const Duration(milliseconds: 1600),
      _runAutoSaveDraft,
    );
  }

  Future<void> _runAutoSaveDraft() async {
    if (!mounted) return;
    final p = context.read<ExpenseProvider>();
    if (!_canAutoSaveDraft(p)) return;
    final signature = _buildAutoDraftSignature(p);
    if (signature == _lastAutoDraftSignature) return;
    setState(() {
      _isAutoSaving = true;
      _autoDraftMessage = TransactionUiText.autoDraftSaving;
    });

    final subData = _buildSubDataPayload(p);
    final totalAmt = _totalAmountString();
    final moneyDomain = _moneyDomainForSave(p);
    final isCheque = _isPayingByCheque(p);
    final payCheque = isCheque
        ? (_chequeLinesKey.currentState?.buildPayload(remark: _remark.text) ??
            <Map<String, dynamic>>[])
        : <Map<String, dynamic>>[];
    var bankAmount = '0';
    if (isCheque && payCheque.isNotEmpty) {
      bankAmount = payCheque
          .fold<double>(
            0,
            (s, r) =>
                s +
                (double.tryParse(r['chequeamount']?.toString() ?? '0') ?? 0),
          )
          .toStringAsFixed(2);
    }

    final localId = await p.upsertAutoDraft(
      localId: _autoDraftLocalId,
      token: token ?? '',
      docno: _docno.text,
      docdate: docDate,
      amount: totalAmt,
      detail: _detail.text,
      remark: _remark.text,
      partyName: _payTo.text.trim(),
      refMember: userId ?? '',
      subData: subData,
      payCheque: payCheque,
      bankAmount: bankAmount,
      moneyDomain: moneyDomain,
      refExpenseReq: _expenseReqPrefill?.expenseReqId,
      refExpenseReqServerId: _expenseReqPrefill?.expenseReqServerId,
    );
    if (!mounted) return;
    setState(() {
      _isAutoSaving = false;
      if (localId == null) {
        _autoDraftMessage = TransactionUiText.autoDraftFailed;
      } else {
        _autoDraftLocalId = localId;
        _lastAutoDraftSignature = signature;
        _autoDraftMessage = TransactionUiText.autoDraftSaved;
      }
    });
  }

  Future<void> _saveOnPressed() async {
    if (!_isEditMode) {
      await _refreshDocNoForSelectedDate();
    }

    final valid = await _checkDataBeforeInsert();
    if (!valid) return;

    if (_isEditMode) {
      final reason = await _promptEditReason();
      if (!mounted || reason == null) return;
      await _performSave(changeReason: reason);
      return;
    }
    await _performSave();
  }

  Future<void> _performSave({String? changeReason}) async {
    final subData = _buildSubDataPayload(expenseProvider);
    final totalAmt = _totalAmountString();
    final moneyDomain = _moneyDomainForSave(expenseProvider);

    final isCheque = _isPayingByCheque(expenseProvider);
    final payCheque = isCheque
        ? (_chequeLinesKey.currentState?.buildPayload(remark: _remark.text) ??
            <Map<String, dynamic>>[])
        : <Map<String, dynamic>>[];
    var bankAmount = '0';
    if (isCheque && payCheque.isNotEmpty) {
      bankAmount = payCheque
          .fold<double>(
            0,
            (s, r) =>
                s +
                (double.tryParse(r['chequeamount']?.toString() ?? '0') ?? 0),
          )
          .toStringAsFixed(2);
    }

    final success = _isEditMode || _autoDraftLocalId != null
        ? await expenseProvider.updateExpense(
            localId: _isEditMode
                ? widget.initialData!['id']?.toString() ?? ''
                : _autoDraftLocalId!,
            token: token ?? '',
            docno: _docno.text,
            docdate: docDate,
            amount: totalAmt,
            detail: _detail.text,
            remark: _remark.text,
            partyName: _payTo.text.trim(),
            refMember: userId ?? '',
            subData: subData,
            payCheque: payCheque,
            bankAmount: bankAmount,
            moneyDomain: moneyDomain,
            refExpenseReq: _expenseReqPrefill?.expenseReqId,
            refExpenseReqServerId: _expenseReqPrefill?.expenseReqServerId,
            changeReason: changeReason,
            docStatus: _isEditMode ? null : 'posted',
          )
        : await expenseProvider.saveExpense(
            token: token ?? '',
            docno: _docno.text,
            docdate: docDate,
            amount: totalAmt,
            detail: _detail.text,
            remark: _remark.text,
            partyName: _payTo.text.trim(),
            refMember: userId ?? '',
            subData: subData,
            payCheque: payCheque,
            bankAmount: bankAmount,
            moneyDomain: moneyDomain,
            refExpenseReq: _expenseReqPrefill?.expenseReqId,
            refExpenseReqServerId: _expenseReqPrefill?.expenseReqServerId,
            docStatus: 'posted',
          );

    if (!mounted) return;

    if (success) {
      final prefill = _expenseReqPrefill;
      if (!_isEditMode && prefill != null) {
        await _expenseReqDs.markExpenseRecorded(prefill.expenseReqId);
      }
      _invalidateReceiverRowsCache();
      final headline = _isEditMode
          ? TransactionUiText.updateExpenseSuccess
          : TransactionUiText.saveExpenseSuccess;
      showAutoDismissAlert(
        context,
        TransactionUiText.saveSuccessTitle,
        TransactionUiText.saveSuccessWithLocalServerNote(
          headline,
          serverReachable: false,
        ),
        5,
      );
      _clearInput();
      Navigator.pop(context, true);
    } else {
      showAutoDismissAlert(
        context,
        TransactionUiText.saveFailedTitle,
        expenseProvider.error ?? TransactionUiText.tryAgain,
        null,
      );
    }
  }

  Future<void> _loadPage() async {
    final prefsFuture = SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isExpenseSectionLoading = true);
    }

    if (_isEditMode) {
      // ── Edit mode ──────────────────────────────────────────────────
      // docno มาจาก initialData โดยตรง — ไม่ต้อง fetch เลย → ดับ skeleton ทันที
      final data = widget.initialData!;
      _docno.text = data['docno']?.toString() ?? '';
      setState(() => _isDocNoLoading = false);

      await Future.wait([
        expenseProvider.loadBudgetSources(),
        expenseProvider.loadExpenseTypes(),
        expenseProvider.loadMoneyTypes(),
        expenseProvider.loadOffBudgetFundCategories(),
        expenseProvider.loadChequeAccounts(),
        expenseProvider.loadCashKeepingLimits(),
      ]);
      if (!mounted) return;
      setState(() => _isExpenseSectionLoading = false);

      final prefsData = await prefsFuture;
      token = prefsData.getString("token");
      userId = prefsData.getString("userId");

      unawaited(_checkSetupReadiness());

      _payTo.text = data['partyName']?.toString() ?? '';
      _detail.text = data['detail']?.toString() ?? '';
      _remark.text = data['remark']?.toString() ?? '';
      final rawDate = data['docdate']?.toString();
      if (rawDate != null && rawDate.isNotEmpty) {
        docDate = rawDate;
        final parsedDate = DateTime.tryParse(rawDate);
        if (parsedDate != null && mounted) {
          setState(() => _selectedDocDate = parsedDate);
        }
      }
      final editExpenseType = data['refExpenseType']?.toString() ?? '';
      expenseProvider.addExpenseTypeCode(editExpenseType);
      final editBudgetSource = data['refBudgetSource']?.toString() ?? '';
      expenseProvider.addBudgetSourceCode(editBudgetSource);
      final savedFund = data['refFundCategory']?.toString() ?? '';
      if (expenseProvider.budgetSourceCode.isNotEmpty &&
          _budgetSourceIsOffBudget(expenseProvider)) {
        expenseProvider.addFundCategoryId(savedFund);
      } else {
        expenseProvider.addFundCategoryId('');
      }
      expenseProvider.addMoneyTypeCode(
        data['refMoneyType']?.toString() ?? '',
      );

      final expId = data['id']?.toString() ?? '';
      if (expId.isNotEmpty) {
        final subs = await expenseProvider.loadExpenseSubs(expId);
        final payRows = await expenseProvider.loadPayChequeRows(expId);
        if (!mounted) return;
        _applyExpenseLinesFromSubs(subs, data);
        _initialPayChequeRows =
            payRows.isEmpty ? null : List<Map<String, dynamic>>.from(payRows);
        if (mounted) setState(() {});
      }

      final loadedParty = _payTo.text.trim();
      if (loadedParty.isNotEmpty) {
        final receiverRows = await _loadReceiverPartyRows(forceRefresh: true);
        if (!mounted) return;
        final canon = _canonicalReceiverNameFromRows(loadedParty, receiverRows);
        if (canon == null) {
          _payTo.text = '';
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showSnack(TransactionUiText.payToStaleEditCleared);
            }
          });
        } else {
          _payTo.text = canon;
        }
      }

      _initialBudgetSourceCode = expenseProvider.budgetSourceCode;
      _initialExpenseTypeCode = expenseProvider.expenseTypeCode;
      _initialFundCategoryId = expenseProvider.fundCategoryId;
      _initialMoneyTypeCode = expenseProvider.moneyTypeCode;
      _captureInitialSnapshot();
      _warmReceiverPartyCacheInBackground();
      return;
    }

    // ── Add mode ───────────────────────────────────────────────────
    // warm cache เริ่มก่อนทุกอย่าง
    _warmReceiverPartyCacheInBackground();

    // lookups + fetchDocNo เริ่มพร้อมกัน — แต่ละกลุ่ม setState ตัวเองเมื่อเสร็จ
    final docDateStr = docDate.split(' ')[0];
    await Future.wait([
      Future.wait([
        expenseProvider.loadBudgetSources(),
        expenseProvider.loadExpenseTypes(),
        expenseProvider.loadMoneyTypes(),
        expenseProvider.loadOffBudgetFundCategories(),
        expenseProvider.loadChequeAccounts(),
        expenseProvider.loadCashKeepingLimits(),
      ]),
      expenseProvider
          .fetchDocNo(tableName: 'expense', docDate: docDateStr)
          .then((docNo) {
        if (!mounted) return;
        if (docNo != null) _docno.text = docNo;
        setState(() => _isDocNoLoading = false);
      }),
    ]);

    if (!mounted) return;
    setState(() => _isExpenseSectionLoading = false);

    final prefsData = await prefsFuture;
    token = prefsData.getString("token");
    userId = prefsData.getString("userId");

    unawaited(_checkSetupReadiness());
    _captureInitialSnapshot();
    _warmReceiverPartyCacheInBackground();
  }

  void _onExpenseTypeChanged(ExpenseProvider provider, String expenseTypeCode) {
    provider.addExpenseTypeCode(expenseTypeCode);
    _applyDefaultBudgetSourceForExpenseType(provider, expenseTypeCode);
    _scheduleAutoSave();
  }

  void _onBudgetSourceChanged(ExpenseProvider p, String? code) {
    p.addBudgetSourceCode(code ?? '');
    if (!_budgetSourceIsOffBudget(p)) {
      p.addFundCategoryId('');
    }
    _scheduleAutoSave();
  }

  /// เมื่อเปลี่ยนรูปแบบการจ่าย — ถ้าไม่ใช่เช็คให้ล้างข้อมูลเช็คทิ้ง
  void _onMoneyTypeChanged(ExpenseProvider p, String? code) {
    p.addMoneyTypeCode(code ?? '');
    if (!_isPayingByCheque(p)) {
      p.addChequeAccountId('');
      _initialPayChequeRows = null;
    }
    _scheduleAutoSave();
  }

  /// อ่าน OB code ของ fundCategory ที่เลือก (เช่น "OB-09") เพื่อ resolve fund_kind
  String _selectedOffBudgetCode(ExpenseProvider p) {
    if (p.fundCategoryId.isEmpty) return '';
    for (final row in p.offBudgetFundCategories) {
      if (row.isNotEmpty && row[0] == p.fundCategoryId) {
        return row.length > 2 ? row[2] : '';
      }
    }
    return '';
  }

  /// อ่าน master code ของ budgetSource ที่เลือก ('GOV' / 'NONGOV')
  String? _selectedBudgetMasterCode(ExpenseProvider p) {
    if (p.budgetSourceCode.isEmpty) return null;
    for (final row in p.budgetSource) {
      if (row.length < 2 || row[0] != p.budgetSourceCode) continue;
      return ExpenseBudgetSourceRule.masterCodeFromBudgetRowLabel(row[1]);
    }
    return null;
  }

  /// คืนข้อความ "วงเงินเก็บรักษา" สำหรับการจ่ายชุดนี้ — null เมื่อไม่มี keep limit
  /// (เช่น GOV) หรือยังเลือกแหล่งเงินไม่ครบ
  String? _buildKeepLimitHint(ExpenseProvider p) {
    if (p.budgetSourceCode.isEmpty || p.cashKeepingLimits.isEmpty) {
      return null;
    }
    final master = _selectedBudgetMasterCode(p);
    final obCode = _selectedOffBudgetCode(p);
    final fundKind = CashKeepingFundRule.resolveFundKind(
      budgetSourceMasterCode: master,
      offBudgetCode: obCode,
    );
    if (fundKind == null) return null;
    final limits = p.cashKeepingLimits[fundKind] ??
        p.cashKeepingLimits[CashKeepingFundRule.schoolRevenue];
    if (limits == null) return null;
    final cashMax = limits['cash_max'] ?? 0;
    final bankMax = limits['bank_max'] ?? 0;
    return TransactionUiText.expenseKeepLimitHint(
      fundLabel: CashKeepingFundRule.labelOf(fundKind),
      cashMax: cashMax,
      bankMax: bankMax,
    );
  }

  /// คืนแถว money_type ที่เลือก ([id, name, code]) หรือ const []
  List<String> _selectedMoneyTypeRow(ExpenseProvider p) {
    if (p.moneyTypeCode.isEmpty) return const [];
    for (final row in p.moneyTypes) {
      if (row.isNotEmpty && row[0] == p.moneyTypeCode) return row;
    }
    return const [];
  }

  /// ตัดสินว่ารูปแบบการจ่ายที่เลือกคือ "เช็ค" หรือไม่ (ใช้แสดง section pay_cheque)
  bool _isPayingByCheque(ExpenseProvider p) {
    final row = _selectedMoneyTypeRow(p);
    if (row.isEmpty) return false;
    final name = row.length > 1 ? row[1] : '';
    final code = row.length > 2 ? row[2] : '';
    return MoneyTypePocket.isCheque(code: code, name: name);
  }

  /// ตัดสินว่าแหล่งเงินที่เลือกเป็น "นอกงบประมาณ" หรือไม่ — ใช้ canonical rule
  /// (`ExpenseBudgetSourceRule.masterCodeFromBudgetRowLabel`) แทน keyword matching
  /// เพื่อรองรับ master code ใหม่ ๆ ที่อาจเพิ่มในอนาคต
  bool _budgetSourceIsOffBudget(ExpenseProvider p) {
    if (p.budgetSourceCode.isEmpty) return false;
    for (final row in p.budgetSource) {
      if (row.length < 2 || row[0] != p.budgetSourceCode) continue;
      final masterCode =
          ExpenseBudgetSourceRule.masterCodeFromBudgetRowLabel(row[1]);
      if (masterCode == null) continue;
      return masterCode != 'GOV';
    }
    return false;
  }

  Future<void> _openIncomeTypeManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => IncomeTypeProvider(
            moneyType: [],
            sourceGroups: [],
          ),
          child: const IncomeType(),
        ),
      ),
    );
    if (!mounted) return;
    await expenseProvider.loadOffBudgetFundCategories();
    setState(() {});
  }

  Future<void> _openBudgetSourcePage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const BudgetSourcePage(),
      ),
    );
    if (!mounted) return;
    await expenseProvider.loadBudgetSources();
    if (expenseProvider.expenseTypeCode.isNotEmpty) {
      _applyDefaultBudgetSourceForExpenseType(
        expenseProvider,
        expenseProvider.expenseTypeCode,
      );
    }
    setState(() {});
  }

  void _applyDefaultBudgetSourceForExpenseType(
    ExpenseProvider provider,
    String expenseTypeCode,
  ) {
    if (expenseTypeCode.isEmpty || provider.budgetSource.isEmpty) return;

    final expenseTypeRow = provider.expenseTypes.firstWhere(
      (item) => item.isNotEmpty && item[0] == expenseTypeCode,
      orElse: () => const <String>[],
    );
    final mappedBudgetSourceId =
        expenseTypeRow.length > 2 ? expenseTypeRow[2] : '';
    if (mappedBudgetSourceId.isNotEmpty &&
        provider.budgetSource
            .any((s) => s.isNotEmpty && s[0] == mappedBudgetSourceId)) {
      provider.addBudgetSourceCode(mappedBudgetSourceId);
      return;
    }
    final lastUsed = provider.lastUsedBudgetSourceCode;
    if (lastUsed.isNotEmpty &&
        provider.budgetSource.any((s) => s.isNotEmpty && s[0] == lastUsed)) {
      provider.addBudgetSourceCode(lastUsed);
      return;
    }
    // fallback: auto-select รายการแรกที่มีอยู่ เพื่อให้ฟอร์มทำงานต่อได้ทันที
    provider.addBudgetSourceCode(provider.budgetSource.first[0]);
  }

  void _clearInput() {
    _docno.text = '';
    _payTo.text = '';
    _detail.text = '';
    _remark.text = '';
    _initialPayChequeRows = null;
    _resetExpenseLinesToSingleEmpty();
    _autoSaveDebounce?.cancel();
    _autoDraftLocalId = null;
    _lastAutoDraftSignature = null;
    _autoDraftMessage = TransactionUiText.autoDraftWaiting;
  }

  Future<bool> _checkDataBeforeInsert() async {
    if (_docno.text.trim().isEmpty) {
      _showSnack(TransactionUiText.expenseDocNoCreateFailed);
      return false;
    }
    if (expenseProvider.expenseTypeCode.isEmpty) {
      _showSnack(TransactionUiText.selectExpenseType);
      return false;
    }
    if (expenseProvider.expenseTypeCode.isNotEmpty &&
        expenseProvider.budgetSource.isEmpty) {
      await _promptNavigateToFixExpenseTypeBudgetSource();
      return false;
    }
    if (expenseProvider.budgetSourceCode.isEmpty) {
      if (expenseProvider.expenseTypeCode.isNotEmpty) {
        await _promptNavigateToFixExpenseTypeBudgetSource();
      } else {
        _showSnack(TransactionUiText.selectBudgetSource);
      }
      return false;
    }
    if (_payTo.text.trim().isEmpty) {
      _showSnack(TransactionUiText.payToRequired);
      return false;
    }
    if (_detail.text.trim().isEmpty) {
      _showSnack(TransactionUiText.expenseDetailRequiredError);
      return false;
    }
    final receiverRows = await _loadReceiverPartyRows(forceRefresh: true);
    if (!mounted) return false;
    if (receiverRows.isEmpty) {
      await _promptNavigateToAddReceiverParty();
      return false;
    }
    final partyCanon =
        _canonicalReceiverNameFromRows(_payTo.text, receiverRows);
    if (partyCanon == null) {
      _showSnack(TransactionUiText.payToMustBeRegistered);
      return false;
    }
    if (_payTo.text.trim() != partyCanon) {
      _payTo.text = partyCanon;
    }
    for (final r in _expenseLineRows) {
      final t = r.amount.text.trim();
      if (t.isEmpty) {
        _showSnack(TransactionUiText.fillAmount);
        return false;
      }
      if (_parseAmount(t) <= 0) {
        _showSnack(TransactionUiText.amountMustPositive);
        return false;
      }
    }
    if (expenseProvider.moneyTypeCode.isEmpty) {
      _showSnack(TransactionUiText.expenseSelectMoneyChannel);
      return false;
    }
    if (_budgetSourceIsOffBudget(expenseProvider)) {
      if (expenseProvider.offBudgetFundCategories.isEmpty) {
        _showSnack(TransactionUiText.expenseNoObCategoriesHint);
        return false;
      }
      if (expenseProvider.fundCategoryId.isEmpty) {
        _showSnack(TransactionUiText.expenseSelectFundCategory);
        return false;
      }
    }
    if (_isPayingByCheque(expenseProvider)) {
      final err = _chequeLinesKey.currentState?.validate();
      if (err != null) {
        _showSnack(err);
        return false;
      }
    }
    return true;
  }

  bool _isFormReady(ExpenseProvider p) {
    final offReady = !_budgetSourceIsOffBudget(p) ||
        (p.fundCategoryId.isNotEmpty && p.offBudgetFundCategories.isNotEmpty);
    final chequeReady = !_isPayingByCheque(p) ||
        _chequeLinesKey.currentState?.validate() == null;
    return p.expenseTypeCode.isNotEmpty &&
        p.budgetSourceCode.isNotEmpty &&
        p.moneyTypeCode.isNotEmpty &&
        offReady &&
        chequeReady &&
        _payTo.text.trim().isNotEmpty &&
        _detail.text.trim().isNotEmpty &&
        _sumLineAmounts() > 0;
  }

  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
    _scheduleAutoSave();
  }

  String _buildMissingRequiredText(ExpenseProvider p) {
    final missing = <String>[];
    if (p.expenseTypeCode.isEmpty) {
      missing.add(TransactionUiText.expenseTypeTitle);
    }
    if (p.budgetSourceCode.isEmpty) {
      missing.add(TransactionUiText.budgetSourceTitle);
    }
    if (p.moneyTypeCode.isEmpty) {
      missing.add(TransactionUiText.expenseMoneyChannelTitle);
    }
    if (_budgetSourceIsOffBudget(p)) {
      if (p.fundCategoryId.isEmpty) {
        missing.add(TransactionUiText.expenseFundCategoryTitle);
      }
    }
    if (_payTo.text.trim().isEmpty) missing.add(TransactionUiText.payTo);
    if (_detail.text.trim().isEmpty) missing.add(TransactionUiText.detail);
    if (_sumLineAmounts() <= 0) missing.add(TransactionUiText.amount);
    if (_isPayingByCheque(p) &&
        _chequeLinesKey.currentState?.validate() != null) {
      missing.add(TransactionUiText.expenseChequeStepLabel);
    }
    if (missing.isEmpty) return TransactionUiText.expenseReadyToSave;
    return '${TransactionUiText.expenseMissingRequiredPrefix}${missing.join(', ')}';
  }

  void _captureInitialSnapshot() {
    _initialDocNo = _docno.text.trim();
    _initialPayTo = _payTo.text.trim();
    _initialDetail = _detail.text.trim();
    _initialAmount = _totalAmountString();
    _initialRemark = _remark.text.trim();
    _initialDocDate = docDate.trim();
    _initialSubLinesSnap = _subLinesSnapshot();
    _initialChequeLinesSnap = _chequeLinesKey.currentState?.snapshot() ?? '';
  }

  bool _hasUnsavedChanges() {
    final currentDocNo = _docno.text.trim();
    final currentPayTo = _payTo.text.trim();
    final currentDetail = _detail.text.trim();
    final currentRemark = _remark.text.trim();
    final currentDocDate = docDate.trim();
    final currentBudgetSourceCode = expenseProvider.budgetSourceCode.trim();
    final subSnap = _subLinesSnapshot();
    final totalStr = _totalAmountString();

    if (_isEditMode) {
      final currentExpenseTypeCode = expenseProvider.expenseTypeCode.trim();
      final currentFund = expenseProvider.fundCategoryId.trim();
      final currentMoney = expenseProvider.moneyTypeCode.trim();
      return currentDocNo != _initialDocNo ||
          currentPayTo != _initialPayTo ||
          currentDetail != _initialDetail ||
          totalStr != _initialAmount ||
          subSnap != _initialSubLinesSnap ||
          currentRemark != _initialRemark ||
          currentDocDate != _initialDocDate ||
          currentBudgetSourceCode != _initialBudgetSourceCode ||
          currentExpenseTypeCode != _initialExpenseTypeCode ||
          currentFund != _initialFundCategoryId ||
          currentMoney != _initialMoneyTypeCode ||
          (_chequeLinesKey.currentState?.snapshot() ?? '') !=
              _initialChequeLinesSnap;
    }

    final linesTouched = _expenseLineRows.length > 1 ||
        _expenseLineRows.any((r) => r.lineRemark.text.trim().isNotEmpty) ||
        (_expenseLineRows.isNotEmpty &&
            _expenseLineRows.first.amount.text.trim().isNotEmpty);

    return currentDocNo != _initialDocNo ||
        currentDocDate != _initialDocDate ||
        currentPayTo.isNotEmpty ||
        currentDetail.isNotEmpty ||
        linesTouched ||
        currentRemark.isNotEmpty ||
        currentBudgetSourceCode.isNotEmpty ||
        expenseProvider.expenseTypeCode.trim().isNotEmpty ||
        expenseProvider.moneyTypeCode.trim().isNotEmpty ||
        expenseProvider.fundCategoryId.trim().isNotEmpty ||
        (_chequeLinesKey.currentState?.snapshot() ?? '').isNotEmpty;
  }

  Future<void> _handleBackNavigation() async {
    if (_isHandlingBackNavigation) return;
    _isHandlingBackNavigation = true;
    FocusScope.of(context).unfocus();
    try {
      if (!_hasUnsavedChanges()) {
        _popPageSafely(false);
        return;
      }

      final shouldLeave = await showFormLeaveConfirmDialog(
        context,
        title: TransactionUiText.expenseUnsavedLeaveTitle,
        message: TransactionUiText.expenseUnsavedLeaveBody,
        cancelText: TransactionUiText.expenseUnsavedStay,
        confirmText: TransactionUiText.expenseUnsavedLeaveWithoutSave,
      );

      if (shouldLeave && mounted) {
        _popPageSafely(false);
      }
    } finally {
      _isHandlingBackNavigation = false;
    }
  }

  void _popPageSafely(bool result) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _confirmAndResetForm() async {
    FocusScope.of(context).unfocus();
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.expenseResetTitle,
        message: TransactionUiText.expenseResetBody,
        cancelText: TransactionUiText.expenseResetCancel,
        confirmText: TransactionUiText.expenseResetConfirm,
        confirmColor: AppColors.of(dialogContext).navy,
      ),
    );
    if (shouldReset != true || !mounted) return;

    expenseProvider.addBudgetSourceCode('');
    expenseProvider.addExpenseTypeCode('');
    expenseProvider.addFundCategoryId('');
    expenseProvider.addMoneyTypeCode('');
    expenseProvider.addChequeAccountId('');
    _expenseReqPrefill = null;
    _payTo.clear();
    _detail.clear();
    _remark.clear();
    _initialPayChequeRows = null;
    _resetExpenseLinesToSingleEmpty();

    final now = DateTime.now();
    setState(() {
      _selectedDocDate = now;
      docDate = now.toString();
    });

    final docDateParts = docDate.split(' ');
    final docNo = await expenseProvider.fetchDocNo(
      tableName: 'expense',
      docDate: docDateParts[0],
    );
    if (!mounted) return;
    _docno.text = docNo ?? '';
    _captureInitialSnapshot();
    _showSnack(TransactionUiText.expenseResetDone);
  }

  Future<void> _refreshDocNoForSelectedDate() async {
    final selectedDate = _selectedDocDate.toIso8601String().split('T').first;
    final docNo = await expenseProvider.fetchDocNo(
      tableName: 'expense',
      docDate: selectedDate,
    );
    if (!mounted || docNo == null || docNo.isEmpty) return;
    _docno.text = docNo;
  }

  static bool _partyRowIsActive(Map<String, dynamic> row) {
    return row['isactive'] == true || row['isactive']?.toString() == '1';
  }

  static bool _partyRowCanActAsReceiver(Map<String, dynamic> row) {
    final role = (row['role'] ?? 'both').toString().toLowerCase().trim();
    return role == 'receiver' || role == 'both';
  }

  Future<List<Map<String, dynamic>>> _loadReceiverPartyRows({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _receiverRowsCache != null &&
        _receiverRowsCacheAt != null &&
        now.difference(_receiverRowsCacheAt!) < _receiverRowsCacheTtl) {
      return _receiverRowsCache!;
    }

    if (!forceRefresh && _receiverRowsInflight != null) {
      return _receiverRowsInflight!;
    }

    if (forceRefresh) {
      _receiverRowsInflight = null;
      _invalidateReceiverRowsCache();
    }

    final work = _loadReceiverPartyRowsImpl();
    if (!forceRefresh) {
      _receiverRowsInflight = work;
    }
    try {
      return await work;
    } finally {
      if (!forceRefresh && identical(_receiverRowsInflight, work)) {
        _receiverRowsInflight = null;
      }
    }
  }

  static List<Map<String, dynamic>> _partyRowsFromPartyNames(
    List<String> names,
  ) {
    return names
        .map(
          (n) => <String, dynamic>{
            'id': n,
            'name': n,
            'role': 'both',
            'isactive': true,
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadReceiverPartyRowsImpl() async {
    final gen = _receiverLoadGeneration;
    if (!mounted) return [];

    var raw = await expenseProvider.loadReceiverPartyRowsLocalForPicker();
    if (!mounted) return [];
    if (raw.isEmpty) {
      await expenseProvider.loadPartyOptions();
      if (!mounted) return [];
      raw = _partyRowsFromPartyNames(expenseProvider.partyOptions);
    }

    unawaited(expenseProvider.refreshPartyMasterCacheFromServer());

    final filtered = _filterReceiverRowsActive(raw);
    if (!mounted) return filtered;
    if (gen == _receiverLoadGeneration) {
      _receiverRowsCache = filtered;
      _receiverRowsCacheAt = DateTime.now();
    }
    return filtered;
  }

  static String? _canonicalReceiverNameFromRows(
    String text,
    List<Map<String, dynamic>> rows,
  ) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final row in rows) {
      final name = (row['name'] ?? '').toString().trim();
      if (name.isNotEmpty && name.toLowerCase() == t) return name;
    }
    return null;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(msg, style: const TextStyle(fontFamily: _fontFamily)),
        ),
      );
  }

  Future<void> _promptNavigateToAddReceiverParty() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => NoPayerPartyPromptDialog(
        dialogTitle: TransactionUiText.payToNoReceiverDialogTitle,
        dialogBody: TransactionUiText.payToNoReceiverDialogBody,
        onGoAddParty: () {
          if (mounted) _openPartyManagementPage();
        },
      ),
    );
  }

  Future<void> _promptNavigateToFixExpenseTypeBudgetSource() async {
    if (!mounted) return;
    final shouldGo = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.expenseBudgetEmptyDialogTitle,
        message: TransactionUiText.expenseBudgetEmptyDialogBody,
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.goManageBudgetSource,
        confirmColor: AppColors.of(dialogContext).navy,
      ),
    );
    if (shouldGo == true && mounted) {
      await _openBudgetSourcePage();
    }
  }

  void _openPartyManagementPage() {
    if (!mounted) return;
    unawaited(
      Navigator.of(context)
          .push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const PartyManagementPage(),
        ),
      )
          .then((_) {
        if (mounted) {
          _invalidateReceiverRowsCache();
          unawaited(_checkSetupReadiness());
        }
      }),
    );
  }
}

class _ExpenseReqPickerSheet extends StatefulWidget {
  const _ExpenseReqPickerSheet({
    required this.loadItems,
    this.selectedValue,
  });

  final Future<List<AppDropdownItem<String>>> Function() loadItems;
  final String? selectedValue;

  @override
  State<_ExpenseReqPickerSheet> createState() => _ExpenseReqPickerSheetState();
}

class _ExpenseReqPickerSheetState extends State<_ExpenseReqPickerSheet> {
  static const _fontFamily = 'Kanit';
  late final TextEditingController _searchController;
  List<AppDropdownItem<String>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await widget.loadItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

    return ColoredBox(
      color: c.cardWhite,
      child: SafeArea(
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: c.cardBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp8,
                  AppTheme.sp12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: AppTheme.sp8),
                    Expanded(
                      child: Text(
                        TransactionUiText.expenseReqReferencePickerTitle,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: TransactionUiText.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp12,
                ),
                child: AppInput(
                  hint: TransactionUiText.expenseReqReferenceSearchHint,
                  controller: _searchController,
                  prefixIcon: const Icon(Icons.search_rounded),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: scheme.primary),
                            const SizedBox(height: AppTheme.sp12),
                            Text(
                              TransactionUiText.expenseReqReferenceLoading,
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildList(context, c, scheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppColors c, ColorScheme scheme) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((item) {
      if (query.isEmpty) return true;
      return item.label.toLowerCase().contains(query) ||
          (item.subtitle?.toLowerCase().contains(query) ?? false);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sp24),
          child: Text(
            TransactionUiText.expenseReqReferenceEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.sp8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: c.cardBorder.withValues(alpha: 0.7),
      ),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final selected = item.value == widget.selectedValue;
        return ListTile(
          leading: Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? scheme.primary : c.textHint,
          ),
          title: Text(
            item.label,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          subtitle: item.subtitle == null
              ? null
              : Text(
                  item.subtitle!,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    color: c.textSecondary,
                  ),
                ),
          onTap: () => Navigator.of(context).pop(item.value),
        );
      },
    );
  }
}

// ─── Animated skeleton shimmer (ไม่ต้องติดตั้ง package เพิ่ม) ────────────────
class _AnimatedSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  final Color baseColor;
  final Color highlightColor;

  const _AnimatedSkeleton({
    required this.width,
    required this.height,
    required this.radius,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_AnimatedSkeleton> createState() => _AnimatedSkeletonState();
}

class _AnimatedSkeletonState extends State<_AnimatedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color:
              Color.lerp(widget.baseColor, widget.highlightColor, _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
