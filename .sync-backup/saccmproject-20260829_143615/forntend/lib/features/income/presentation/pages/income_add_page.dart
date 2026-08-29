// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/constants/money_type_pocket.dart';
import 'package:saccm/features/income/domain/rules/income_money_domain_rule.dart';
import 'package:saccm/features/income/presentation/providers/income_provider.dart';
import 'package:saccm/features/income_type/presentation/pages/income_type_page.dart';
import 'package:saccm/features/income_type/presentation/providers/income_type_provider.dart';
import 'package:saccm/features/party/presentation/pages/party_management_page.dart';
import 'package:saccm/features/register/presentation/pages/register_page.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:saccm/widgets/dialog/form_leave_confirm_dialog.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IncomeAddData extends StatefulWidget {
  const IncomeAddData({
    super.key,
    required this.inputWidth,
    this.initialData,
    this.embeddedInHome = false,
  });
  final double inputWidth;
  final Map<String, dynamic>? initialData;
  final bool embeddedInHome;

  @override
  State<IncomeAddData> createState() => _ComponentsState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _ComponentsState extends State<IncomeAddData> {
  String? token;
  String? userId;
  final _detail = TextEditingController(),
      _receiveFrom = TextEditingController(),
      _docno = TextEditingController(),
      _remark = TextEditingController(),
      _bankReference = TextEditingController(),
      _amount = TextEditingController(),
      _receiptNo = TextEditingController();
  final FocusNode _docnoFocusNode = FocusNode(),
      _receiveFromFocusNode = FocusNode(),
      _detailFocusNode = FocusNode(),
      _amountFocusNode = FocusNode(),
      _bankReferenceFocusNode = FocusNode(),
      _remarkFocusNode = FocusNode(),
      _receiptNoFocusNode = FocusNode();
  late String docDate = DateTime.now().toString();
  DateTime _selectedDocDate = DateTime.now();
  late IncomeProvider incomeProvider;
  String _initialDocNo = '';
  String _initialReceiveFrom = '';
  String _initialDetail = '';
  String _initialAmount = '';
  String _initialRemark = '';
  String _initialBankReference = '';
  String _initialBudgetSourceCode = '';
  String _initialIncomeTypeCode = '';
  String _initialMoneyTypeCode = '';
  String _initialDocDate = '';

  /// บัญชีธนาคารเมื่อรับแบบโอน
  bool _issueReceipt = false;
  String _receiptBookId = '';
  String _receiptNextHint = '';

  /// สถานะเอกสารจากรายการ (โหมดแก้ไข) — สอดคล้อง `doc_status` บนเซิร์ฟเวอร์
  String _editDocStatusRaw = 'posted';
  bool _isHandlingBackNavigation = false;
  bool get _isEditMode => widget.initialData != null;
  Timer? _autoSaveDebounce;
  String? _autoDraftLocalId;
  String? _lastAutoDraftSignature;
  bool _isAutoSaving = false;
  String _autoDraftMessage = TransactionUiText.autoDraftWaiting;

  // ─── Per-field loading flags ──────────────────────────────────────
  /// เลขที่เอกสาร — รอ fetchDocNo (provider ไม่ track — page เป็นคนเรียก)
  bool _isDocNoLoading = true;

  Future<void> _checkSetupReadiness() async {
    await _loadPayerPartyRows(forceRefresh: false);
  }

  Future<void> _openIncomeTypePage({String? initialIncomeTypeId}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => IncomeTypeProvider(
            moneyType: [],
            sourceGroups: [],
          ),
          child: IncomeType(initialIncomeTypeId: initialIncomeTypeId),
        ),
      ),
    );
    if (!mounted) return;
    await incomeProvider.loadIncomeTypes();
    await incomeProvider.loadBudgetSourcesForSelectedIncomeType();
    if (!mounted) return;
    await _checkSetupReadiness();
  }

  /// ลดการยิงซ้ำ — แคช in-memory รายชื่อผู้จ่าย (ข้อมูลมาจาก SQLite เสมอ)
  List<Map<String, dynamic>>? _payerRowsCache;
  DateTime? _payerRowsCacheAt;
  static const _payerRowsCacheTtl = Duration(minutes: 2);
  Future<List<Map<String, dynamic>>>? _payerRowsInflight;
  int _payerLoadGeneration = 0;

  void _invalidatePayerRowsCache() {
    _payerLoadGeneration++;
    _payerRowsCache = null;
    _payerRowsCacheAt = null;
  }

  Future<void> _refreshReceiptNextHint({bool applyToField = false}) async {
    final selectedBookId = _receiptBookId;
    if (!_issueReceipt || selectedBookId.isEmpty) {
      if (mounted) setState(() => _receiptNextHint = '');
      if (applyToField) _receiptNo.clear();
      return;
    }
    final next = await incomeProvider.suggestedNextReceiptNo(selectedBookId);
    if (!mounted || selectedBookId != _receiptBookId) return;
    final nextText = next ?? '';
    final shouldApply = applyToField ||
        (!_receiptNoFocusNode.hasFocus &&
            _receiptNo.text.trim().isEmpty &&
            nextText.isNotEmpty);
    setState(() => _receiptNextHint = nextText);
    if (shouldApply) _receiptNo.text = nextText;
  }

  /// กรองผู้จ่าย + active ในครั้งเดียว (ลดการวนซ้ำ)
  static List<Map<String, dynamic>> _filterPayerRowsActive(
    List<Map<String, dynamic>> raw,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final row in raw) {
      if (!_partyRowIsActive(row) || !_partyRowCanActAsPayer(row)) continue;
      out.add(row);
    }
    return out;
  }

  /// โหลดแคชเบื้องหลัง — เปิดชีตเลือกผู้จ่ายจะได้ข้อมูลจากแคช/in-flight ทันทีบ่อยขึ้น
  /// (โหมดแก้ไขที่มีชื่อผู้จ่ายอยู่แล้วจะโหลดแบบ force แยก — ไม่เรียก warm ซ้ำตอนต้น loadPage)
  void _warmPayerPartyCacheInBackground() {
    unawaited(
      _loadPayerPartyRows(forceRefresh: false).catchError(
        (_, __) => <Map<String, dynamic>>[],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _detail.addListener(_onAnyFieldChanged);
    _receiveFrom.addListener(_onAnyFieldChanged);
    _docno.addListener(_onAnyFieldChanged);
    _remark.addListener(_onAnyFieldChanged);
    _bankReference.addListener(_onAnyFieldChanged);
    _amount.addListener(_onAnyFieldChanged);
    _receiptNo.addListener(_onAnyFieldChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) => loadPage());
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _detail.removeListener(_onAnyFieldChanged);
    _receiveFrom.removeListener(_onAnyFieldChanged);
    _docno.removeListener(_onAnyFieldChanged);
    _remark.removeListener(_onAnyFieldChanged);
    _bankReference.removeListener(_onAnyFieldChanged);
    _amount.removeListener(_onAnyFieldChanged);
    _receiptNo.removeListener(_onAnyFieldChanged);
    _detail.dispose();
    _receiveFrom.dispose();
    _docno.dispose();
    _remark.dispose();
    _bankReference.dispose();
    _amount.dispose();
    _receiptNo.dispose();
    _docnoFocusNode.dispose();
    _receiveFromFocusNode.dispose();
    _detailFocusNode.dispose();
    _amountFocusNode.dispose();
    _bankReferenceFocusNode.dispose();
    _remarkFocusNode.dispose();
    _receiptNoFocusNode.dispose();
    super.dispose();
  }

  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  TextStyle _pageBodyStyle(AppColors c,
      {required double fontSize,
      FontWeight? weight,
      Color? color,
      double? height}) {
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
    // listen: false — ไม่ให้ rebuild ทั้งหน้าเมื่อ provider notify
    // dropdown ใช้ Consumer แยกต่างหาก
    incomeProvider = Provider.of<IncomeProvider>(context, listen: false);
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
                        icon: Icons.south_rounded,
                        iconColor: scheme.primary,
                        iconBgColor: c.iconBgIncome,
                        title: TransactionUiText.incomeItemInfo,
                        subtitle: TransactionUiText.reviewBeforeSave,
                        quickHint: TransactionUiText.requiredBeforeSaveHint,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined, size: 18, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              TransactionUiText.incomeQuickGuideHint,
              style: _pageBodyStyle(c,
                  fontSize: 13, height: 1.35, weight: FontWeight.w600),
            ),
          ),
        ],
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

  Future<void> _showPageGuideDialog() async {
    final c = AppColors.of(context);
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.incomePageGuideTitle,
      items: [
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.requiredBeforeSaveHint,
          backgroundColor: c.iconBgIncome,
        ),
      ],
      children: [_buildQuickGuide(c)],
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: c.cardWhite,
      actions: [
        Consumer<IncomeProvider>(
          builder: (_, p, __) {
            final isReady = _isFormReady(p);
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: AppTheme.sp12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.help_outline_rounded,
                        size: 20, color: c.textSecondary),
                    tooltip: TransactionUiText.incomePageGuideTitle,
                    visualDensity: VisualDensity.compact,
                    onPressed: _showPageGuideDialog,
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
                    label: !_isEditMode && _issueReceipt
                        ? TransactionUiText.incomeSaveAndPrintReceipt
                        : TransactionUiText.save,
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
                  ? TransactionUiText.editIncomeItem
                  : TransactionUiText.incomeRecord,
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

  // ─── Page header ──────────────────────────────────────────────────
  // ─── Form card ────────────────────────────────────────────────────
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
              // ── Section: ข้อมูลเอกสาร ──
              _buildSectionHeader(c,
                  icon: Icons.description_outlined,
                  title: TransactionUiText.documentInfo),
              if (_isEditMode) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.sp16, 0, AppTheme.sp16, AppTheme.sp8),
                  child: _buildEditDocStatusBanner(c),
                ),
              ],
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
                        dateFormat: 'thai_buddhist',
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

              // ── Section: ประเภทและยอดเงิน ──
              _buildSectionHeader(c,
                  icon: Icons.account_balance_wallet_outlined,
                  title: TransactionUiText.amountTypeSection),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.sp16, 0, AppTheme.sp16, AppTheme.sp16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountingStepLabel(
                      c,
                      TransactionUiText.incomeAccountingStep1Label,
                      isFirst: true,
                    ),
                    _buildIncomeTypeBudgetGrid(c, contentWidth, columnCount),
                    const SizedBox(height: AppTheme.sp12),
                    _buildAccountingStepLabel(
                      c,
                      TransactionUiText.incomeAccountingStep2Label,
                    ),
                    _responsiveFieldGrid(
                      contentWidth,
                      columnCount: columnCount,
                      fields: [
                        _ResponsiveFormField(
                          child: Consumer<IncomeProvider>(
                            builder: (_, p, __) => p.isMoneyTypeLoading
                                ? _skeletonField(width: null)
                                : AppLookupPickerField<String>(
                                    label: TransactionUiText.receiveMethod,
                                    items: p.monneyType
                                        .map((e) => AppDropdownItem<String>(
                                            value: e[0], label: e[1]))
                                        .toList(),
                                    value: p.monneyTypeCode.isEmpty
                                        ? null
                                        : p.monneyTypeCode,
                                    clearable: false,
                                    prefixIcon:
                                        const Icon(Icons.payments_outlined),
                                    onChanged: (v) {
                                      p.addMonneyTypeCode(v ?? '');
                                      if (!_shouldShowBankReference(p)) {
                                        _bankReference.clear();
                                      }
                                      _scheduleAutoSave();
                                    },
                                  ),
                          ),
                        ),
                        _ResponsiveFormField(
                          child: AppInput(
                            label: TransactionUiText.amount,
                            hint: '0.00',
                            required: true,
                            helperText: TransactionUiText.positiveAmountHelper,
                            action:
                                const AppInputAction.number(allowDecimal: true),
                            focusNode: _amountFocusNode,
                            controller: _amount,
                            textAlign: TextAlign.right,
                            prefixIcon: const Icon(Icons.attach_money_rounded),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (p0) {
                              if (p0 == null || p0.isEmpty) {
                                return TransactionUiText.fillAmount;
                              }
                              if ((double.tryParse(p0.replaceAll(',', '')) ??
                                      0) <=
                                  0) {
                                return TransactionUiText.amountMustPositive;
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    Consumer<IncomeProvider>(
                      builder: (_, p, __) {
                        if (!_shouldShowBankReference(p)) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppTheme.sp12),
                            _buildBankReferenceNotice(c),
                            const SizedBox(height: AppTheme.sp8),
                            _responsiveFieldGrid(
                              contentWidth,
                              columnCount: columnCount,
                              fields: [
                                _ResponsiveFormField(
                                  span: columnCount >= 2 ? 2 : 1,
                                  child: AppInput(
                                    label: TransactionUiText
                                        .incomeBankReferenceLabel,
                                    hint: TransactionUiText
                                        .incomeBankReferenceHint,
                                    helperText: TransactionUiText
                                        .incomeBankReferenceHelper,
                                    controller: _bankReference,
                                    focusNode: _bankReferenceFocusNode,
                                    prefixIcon: const Icon(
                                      Icons.account_balance_outlined,
                                    ),
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) =>
                                        _detailFocusNode.requestFocus(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    if (!_isEditMode) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.sp12),
                        child: _buildSectionHeader(
                          c,
                          icon: Icons.receipt_long_outlined,
                          title: TransactionUiText.registerReceiptBookTabLabel,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _issueReceipt,
                                onChanged: (v) async {
                                  final on = v ?? false;
                                  setState(() {
                                    _issueReceipt = on;
                                    if (!on) {
                                      _receiptNo.clear();
                                      _receiptBookId = '';
                                      _receiptNextHint = '';
                                    }
                                  });
                                  _scheduleAutoSave();
                                  if (on) await _refreshReceiptNextHint();
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: AppTheme.sp4),
                              Expanded(
                                child: Text(
                                  TransactionUiText.incomeEntryIssueReceipt,
                                  style: _pageBodyStyle(c, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          if (_issueReceipt) ...[
                            _responsiveFieldGrid(
                              contentWidth,
                              columnCount: columnCount,
                              fields: [
                                _ResponsiveFormField(
                                  child: Consumer<IncomeProvider>(
                                    builder: (_, p, __) {
                                      if (p.isReceiptBookLoading) {
                                        return _skeletonField(width: null);
                                      }
                                      if (p.receiptBookOptions.isEmpty) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: AppTheme.sp8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                TransactionUiText
                                                    .incomeNoReceiptBooksHint,
                                                style: _pageBodyStyle(c,
                                                    fontSize: 13,
                                                    color: c.textSecondary),
                                              ),
                                              const SizedBox(
                                                  height: AppTheme.sp8),
                                              TextButton.icon(
                                                onPressed:
                                                    _openReceiptBookRegisterPage,
                                                icon: const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 16),
                                                label: const Text(
                                                  TransactionUiText
                                                      .incomeNoReceiptBooksGoManage,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return AppLookupPickerField<String>(
                                        label: TransactionUiText
                                            .incomeReceiptBookLabel,
                                        required: true,
                                        items: p.receiptBookOptions
                                            .map((e) => AppDropdownItem<String>(
                                                value: e[0], label: e[1]))
                                            .toList(),
                                        value: _receiptBookId.isEmpty
                                            ? null
                                            : _receiptBookId,
                                        clearable: false,
                                        prefixIcon:
                                            const Icon(Icons.receipt_outlined),
                                        onChanged: (v) async {
                                          setState(
                                              () => _receiptBookId = v ?? '');
                                          await _refreshReceiptNextHint(
                                            applyToField: true,
                                          );
                                          _scheduleAutoSave();
                                        },
                                      );
                                    },
                                  ),
                                ),
                                _ResponsiveFormField(
                                  child: _buildReceiptNoField(c),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),

              // ── Section: รายละเอียดเพิ่มเติม ──
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
                      child: _buildReceiveFromField(),
                    ),
                    _ResponsiveFormField(
                      span: columnCount >= 4 ? 2 : 1,
                      child: AppInput(
                        label: TransactionUiText.detail,
                        hint: TransactionUiText.incomeDetailHint,
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

  Widget _buildIncomeTypeBudgetGrid(
    AppColors c,
    double contentWidth,
    int columnCount,
  ) {
    return Consumer<IncomeProvider>(
      builder: (_, p, __) {
        final hasIncomeType = p.incomeTypeCode.isNotEmpty;
        final fields = <_ResponsiveFormField>[
          _ResponsiveFormField(
            child: p.isIncomeTypeLoading
                ? _skeletonField(width: null)
                : AppLookupPickerField<String>(
                    label: TransactionUiText.incomeType,
                    required: true,
                    helperText: TransactionUiText.incomeTypeHelperText,
                    items: p.incomeType
                        .map((e) =>
                            AppDropdownItem<String>(value: e[0], label: e[1]))
                        .toList(),
                    value: p.incomeTypeCode.isEmpty ? null : p.incomeTypeCode,
                    clearable: false,
                    prefixIcon: const Icon(Icons.category_outlined),
                    onChanged: (v) => _onIncomeTypeChanged(p, v ?? ''),
                  ),
          ),
        ];

        if (!p.isIncomeTypeLoading && hasIncomeType) {
          final incomeTypeCode = _getIncomeTypeCodeById(p, p.incomeTypeCode);
          final domain = incomeTypeCode.isNotEmpty
              ? IncomeMoneyDomainRule.inferFromCode(incomeTypeCode)
              : IncomeMoneyDomainRule.inferFromLookupId(p.incomeTypeCode);
          final domainThai = TransactionUiText.incomeMoneyDomainThai(domain);
          fields.add(
            _ResponsiveFormField(
              child: _buildMoneyDomainReadOnly(domainThai),
            ),
          );
        }

        fields.add(
          _ResponsiveFormField(
            span: columnCount >= 4 ? 2 : 1,
            child: _buildBudgetSourceSelector(c, p),
          ),
        );

        return _responsiveFieldGrid(
          contentWidth,
          columnCount: columnCount,
          fields: fields,
        );
      },
    );
  }

  Widget _buildBudgetSourceSelector(AppColors c, IncomeProvider p) {
    if (p.isIncomeTypeLoading || p.isBudgetSourceLoading) {
      return _skeletonField(width: null);
    }

    final scheme = Theme.of(context).colorScheme;
    final hasIncomeType = p.incomeTypeCode.isNotEmpty;
    final noBudgetSourceForType = hasIncomeType && p.budgetSource.isEmpty;
    final selectedIncomeTypeName =
        _getIncomeTypeNameByCode(p, p.incomeTypeCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasIncomeType &&
            !noBudgetSourceForType &&
            p.budgetSource.length == 1)
          _buildLinkedBudgetReadOnly(p)
        else
          AppLookupPickerField<String>(
            label: TransactionUiText.budgetSourceTitle,
            required: true,
            enabled: hasIncomeType && !noBudgetSourceForType,
            hint: hasIncomeType
                ? (noBudgetSourceForType
                    ? TransactionUiText.incomeNoBudgetInCategoryHint
                    : null)
                : TransactionUiText.incomeChooseCategoryFirstHint,
            hintStyle: noBudgetSourceForType
                ? TextStyle(
                    color: scheme.error,
                    fontFamily: 'Kanit',
                    fontWeight: FontWeight.w600,
                  )
                : null,
            helperText: hasIncomeType
                ? (noBudgetSourceForType
                    ? TransactionUiText.incomeNoBudgetInCategoryHelper
                    : TransactionUiText.incomeBudgetSourceWhenCategoryOkHelper)
                : TransactionUiText.incomeBudgetSourceSelectLockedHelper,
            helperStyle: noBudgetSourceForType
                ? TextStyle(
                    color: scheme.error,
                    fontFamily: 'Kanit',
                    fontWeight: FontWeight.w600,
                  )
                : null,
            items: hasIncomeType
                ? p.budgetSource
                    .map((e) =>
                        AppDropdownItem<String>(value: e[0], label: e[1]))
                    .toList()
                : const [],
            value: hasIncomeType && p.budgetSourceCode.isNotEmpty
                ? p.budgetSourceCode
                : null,
            clearable: false,
            prefixIcon: const Icon(Icons.account_balance_outlined),
            onChanged: hasIncomeType && !noBudgetSourceForType
                ? (v) {
                    p.addBudgetSourceCode(v ?? '');
                    _scheduleAutoSave();
                  }
                : null,
          ),
        if (hasIncomeType && !noBudgetSourceForType) ...[
          const SizedBox(height: AppTheme.sp8),
          _buildIncomeBudgetFilterBanner(context, c),
        ],
        if (noBudgetSourceForType) ...[
          const SizedBox(height: AppTheme.sp8),
          TextButton.icon(
            onPressed: () => _openIncomeTypePage(
              initialIncomeTypeId: p.incomeTypeCode,
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(
              selectedIncomeTypeName.isEmpty
                  ? TransactionUiText.incomeGoFixBudgetInIncomeTypePage
                  : TransactionUiText.incomeGoFixBudgetInIncomeTypePageNamed(
                      selectedIncomeTypeName,
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMoneyDomainReadOnly(String domainThai) {
    return AppInput(
      key: ValueKey('income_money_domain_$domainThai'),
      label: TransactionUiText.incomeMoneyDomainLabel,
      initialValue: domainThai,
      helperText: TransactionUiText.incomeMoneyDomainHelper,
      readOnly: true,
      enabled: false,
      prefixIcon: const Icon(Icons.category_outlined),
    );
  }

  Widget _buildLinkedBudgetReadOnly(IncomeProvider p) {
    final label = p.budgetSource.isNotEmpty && p.budgetSource.first.length >= 2
        ? p.budgetSource.first[1]
        : '';
    return AppInput(
      key: ValueKey('income_linked_budget_$label'),
      label: TransactionUiText.budgetSourceTitle,
      initialValue: label,
      helperText: TransactionUiText.incomeBudgetLinkedAuto,
      readOnly: true,
      enabled: false,
      prefixIcon: const Icon(Icons.link_rounded),
    );
  }

  Widget _buildReceiptNoField(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          label: TransactionUiText.incomeReceiptNoLabel,
          hint: TransactionUiText.incomeReceiptNoHint,
          required: true,
          controller: _receiptNo,
          focusNode: _receiptNoFocusNode,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _receiptNoBookValidationError,
        ),
        if (_receiptNextHint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.sp8,
              left: AppTheme.sp4,
            ),
            child: Text(
              TransactionUiText.incomeReceiptNoSuggestedNext(_receiptNextHint),
              style: _pageBodyStyle(
                c,
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReceiveFromField() {
    return ListenableBuilder(
      listenable: _receiveFrom,
      builder: (context, _) {
        final selectedPayer = _receiveFrom.text.trim();
        return AppLookupPickerField<String>(
          label: TransactionUiText.receiveFrom,
          hint: TransactionUiText.receiveFromHint,
          helperText: TransactionUiText.receiveFromHelperRegisteredOnly,
          required: true,
          value: selectedPayer.isEmpty ? null : selectedPayer,
          displayLabel: selectedPayer.isEmpty ? null : selectedPayer,
          clearable: false,
          pickerTitle: TransactionUiText.incomePayerPickerTitle,
          searchHint: TransactionUiText.incomePayerPickerSearchHint,
          loadingText: TransactionUiText.incomePayerPickerLoading,
          emptyText: TransactionUiText.receiveFromNoPayerDialogBody,
          emptyActionLabel: TransactionUiText.receiveFromGoAddParty,
          onEmptyAction: _openPartyManagementPage,
          loadItems: _loadPayerLookupItems,
          onChanged: (v) {
            final selectedName = v?.trim() ?? '';
            if (selectedName.isEmpty) return;
            setState(() => _receiveFrom.text = selectedName);
            _detailFocusNode.requestFocus();
          },
          prefixIcon: const Icon(Icons.person_outline_rounded),
        );
      },
    );
  }

  Future<List<AppDropdownItem<String>>> _loadPayerLookupItems() async {
    final rows = await _loadPayerPartyRows();
    return rows.map((row) {
      final role = (row['role'] ?? 'both').toString().toLowerCase();
      final name = (row['name'] ?? '').toString();
      return AppDropdownItem<String>(
        value: name,
        label: name,
        subtitle: role == 'both'
            ? TransactionUiText.incomePayerRoleBoth
            : TransactionUiText.incomePayerRolePayer,
      );
    }).toList();
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool _matchesReceiptNoTemplate(String value, String template) {
    final normalizedValue = value.trim();
    final normalizedTemplate = template.trim();
    if (normalizedValue.isEmpty || _digitsOnly(normalizedTemplate).isEmpty) {
      return false;
    }

    final digitRun = RegExp(r'\d+');
    final buffer = StringBuffer('^');
    var cursor = 0;
    for (final match in digitRun.allMatches(normalizedTemplate)) {
      buffer
        ..write(
            RegExp.escape(normalizedTemplate.substring(cursor, match.start)))
        ..write('\\d{${match.group(0)!.length}}');
      cursor = match.end;
    }
    buffer
      ..write(RegExp.escape(normalizedTemplate.substring(cursor)))
      ..write(r'$');
    return RegExp(buffer.toString()).hasMatch(normalizedValue);
  }

  bool _receiptNoMatchesBookFormat({
    required String receiptNo,
    required String startNo,
    required String endNo,
  }) {
    if (_matchesReceiptNoTemplate(receiptNo, startNo)) return true;
    if (endNo.trim().isNotEmpty && endNo.trim() != startNo.trim()) {
      return _matchesReceiptNoTemplate(receiptNo, endNo);
    }
    return false;
  }

  String? _receiptNoBookValidationError(String? value) {
    if (!_issueReceipt || _receiptBookId.isEmpty) return null;
    final receiptNo = (value ?? _receiptNo.text).trim();
    if (receiptNo.isEmpty) return null;

    final book = incomeProvider.receiptBookById(_receiptBookId);
    final startRaw = book?['start_no']?.toString().trim() ?? '';
    final endRaw = book?['end_no']?.toString().trim() ?? '';
    if (startRaw.isEmpty) return null;

    if (!_receiptNoMatchesBookFormat(
      receiptNo: receiptNo,
      startNo: startRaw,
      endNo: endRaw,
    )) {
      final example = _receiptNextHint.isNotEmpty ? _receiptNextHint : startRaw;
      return TransactionUiText.incomeReceiptNoMustMatchBookFormat(example);
    }

    final receiptNumber = int.tryParse(_digitsOnly(receiptNo));
    if (receiptNumber == null) return null;

    final endNumber = int.tryParse(_digitsOnly(endRaw));
    if (endNumber == null) return null;

    if (receiptNumber > endNumber) {
      return TransactionUiText.incomeReceiptNoExceedsBookEnd(endRaw);
    }
    return null;
  }

  // ─── Summary + Save button row ────────────────────────────────────
  Widget _buildActionRow(AppColors c) {
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0.0;
    return Consumer<IncomeProvider>(
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
              amountColor: c.incomeGreen,
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
      AppColors c, IncomeProvider p, bool isReadyToSave) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp12, vertical: AppTheme.sp8),
      decoration: BoxDecoration(
        color: isReadyToSave ? c.iconBgIncome : c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(
          color: isReadyToSave
              ? c.incomeGreen.withValues(alpha: 0.6)
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
            color: isReadyToSave ? c.incomeGreen : c.textSecondary,
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              isReadyToSave
                  ? TransactionUiText.incomeReadyToSave
                  : _buildMissingRequiredText(p),
              style: _pageBodyStyle(
                c,
                fontSize: 13,
                height: 1.35,
                color: isReadyToSave ? c.incomeGreen : c.textPrimary,
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
        : (_isAutoSaving ? c.incomeGreen : c.textSecondary);
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

  // ─── Section header ───────────────────────────────────────────────
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

  Widget _buildIncomeBudgetFilterBanner(BuildContext context, AppColors c) {
    final accent = Theme.of(context).colorScheme.primary;
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
              TransactionUiText.incomeBudgetFilteredByCategoryBanner,
              style: _pageBodyStyle(c, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Save ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _buildIncomeSubData() {
    return [
      {
        "refincometype": incomeProvider.incomeTypeCode,
        "refmoneytype": incomeProvider.monneyTypeCode,
        "amount": _amount.text,
        "remark": _remark.text,
        "detail": _detail.text.trim(),
      }
    ];
  }

  bool _canAutoSaveDraft(IncomeProvider p) {
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    return !_isEditMode &&
        (token?.isNotEmpty ?? false) &&
        (userId?.isNotEmpty ?? false) &&
        _docno.text.trim().isNotEmpty &&
        p.incomeTypeCode.isNotEmpty &&
        !_isDepositRegisterIncomeType(p) &&
        p.budgetSourceCode.isNotEmpty &&
        _receiveFrom.text.trim().isNotEmpty &&
        amount > 0 &&
        (!_issueReceipt ||
            (_receiptBookId.isNotEmpty && _receiptNo.text.trim().isNotEmpty));
  }

  String _buildAutoDraftSignature(IncomeProvider p) {
    final amount = (double.tryParse(_amount.text.replaceAll(',', '')) ?? 0)
        .toStringAsFixed(2);
    return [
      _docno.text.trim(),
      docDate,
      p.incomeTypeCode,
      p.budgetSourceCode,
      p.monneyTypeCode,
      _receiveFrom.text.trim(),
      _detail.text.trim(),
      _remark.text.trim(),
      _bankReference.text.trim(),
      amount,
      _issueReceipt.toString(),
      _receiptBookId,
      _receiptNo.text.trim(),
    ].join('|');
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    if (!mounted) return;
    final p = context.read<IncomeProvider>();
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
    final p = context.read<IncomeProvider>();
    if (!_canAutoSaveDraft(p)) return;
    final signature = _buildAutoDraftSignature(p);
    if (signature == _lastAutoDraftSignature) return;
    setState(() {
      _isAutoSaving = true;
      _autoDraftMessage = TransactionUiText.autoDraftSaving;
    });
    final localId = await p.upsertAutoDraft(
      localId: _autoDraftLocalId,
      token: token ?? '',
      docno: _docno.text,
      docdate: docDate,
      amount: _amount.text,
      detail: _composeDetailForSave(),
      remark: _remark.text,
      bankReference: _bankReference.text.trim(),
      partyName: _receiveFrom.text.trim(),
      refUser: userId ?? '',
      subData: _buildIncomeSubData(),
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

  String _incomeDocStatusDisplayLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'draft':
        return TransactionUiText.incomeDocStatusDraft;
      case 'approved':
        return TransactionUiText.incomeDocStatusApproved;
      case 'posted':
      default:
        return TransactionUiText.incomeDocStatusPosted;
    }
  }

  Color _incomeDocStatusAccent(AppColors c, String raw) {
    switch (raw.toLowerCase()) {
      case 'draft':
        return c.textSecondary;
      case 'approved':
        return Colors.orange.shade700;
      case 'posted':
      default:
        return c.incomeGreen;
    }
  }

  Widget _buildEditDocStatusBanner(AppColors c) {
    final accent = _incomeDocStatusAccent(c, _editDocStatusRaw);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp12, vertical: AppTheme.sp8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, size: 18, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: _pageBodyStyle(c, fontSize: 12, height: 1.35),
                children: [
                  TextSpan(
                    text: '${TransactionUiText.incomeDocStatusLabel}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: _incomeDocStatusDisplayLabel(_editDocStatusRaw),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _saveOnPressed() async {
    await _saveWithOptions(openPrintSummary: !_isEditMode && _issueReceipt);
  }

  Future<void> _saveWithOptions({required bool openPrintSummary}) async {
    if (!_isEditMode) {
      await _refreshDocNoForSelectedDate();
    }

    final valid = await _checkDataBeforeInsert();
    if (!valid) return;

    if (_isEditMode) {
      final reason = await _promptEditReason();
      if (!mounted || reason == null) return;
      await _performSave(changeReason: reason, openPrintSummary: false);
      return;
    }
    await _performSave(openPrintSummary: openPrintSummary);
  }

  Future<void> _performSave({
    String? changeReason,
    bool openPrintSummary = false,
  }) async {
    final refParty = await _refPartyIdForSave();
    final subData = _buildIncomeSubData();

    final success = _isEditMode || _autoDraftLocalId != null
        ? await incomeProvider.updateIncome(
            localId: _isEditMode
                ? widget.initialData!['id']?.toString() ?? ''
                : _autoDraftLocalId!,
            token: token ?? '',
            docno: _docno.text,
            docdate: docDate,
            amount: _amount.text,
            detail: _composeDetailForSave(),
            remark: _remark.text,
            bankReference: _bankReference.text.trim(),
            partyName: _receiveFrom.text.trim(),
            refUser: userId ?? '',
            subData: subData,
            changeReason: changeReason,
            refBankAccount: null,
            receiptBookId:
                !_isEditMode && _issueReceipt ? _receiptBookId : null,
            receiptNo:
                !_isEditMode && _issueReceipt ? _receiptNo.text.trim() : null,
            docStatus: _isEditMode ? null : 'posted',
          )
        : await incomeProvider.saveIncome(
            token: token ?? '',
            docno: _docno.text,
            docdate: docDate,
            amount: _amount.text,
            detail: _composeDetailForSave(),
            remark: _remark.text,
            bankReference: _bankReference.text.trim(),
            partyName: _receiveFrom.text.trim(),
            refParty: refParty,
            refUser: userId ?? '',
            subData: subData,
            receiptBookId: _issueReceipt ? _receiptBookId : null,
            receiptNo: _issueReceipt ? _receiptNo.text.trim() : null,
            docStatus: 'posted',
          );

    if (!mounted) return;

    if (success) {
      _invalidatePayerRowsCache();
      if (!_isEditMode && openPrintSummary && _issueReceipt) {
        await _showReceiptPrintSummary();
      }
      if (!mounted) return;
      final headline = _isEditMode
          ? TransactionUiText.updateIncomeSuccess
          : TransactionUiText.saveIncomeSuccess;
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
      showAutoDismissAlert(context, TransactionUiText.saveFailedTitle,
          incomeProvider.error ?? TransactionUiText.tryAgain, null);
    }
  }

  Future<void> loadPage() async {
    final prefsFuture = SharedPreferences.getInstance();

    if (_isEditMode) {
      // ── Edit mode ──────────────────────────────────────────────────
      // docno มาจาก initialData โดยตรง — ไม่ต้อง fetch เลย → ดับ skeleton ทันที
      final data = widget.initialData!;
      _docno.text = data['docno']?.toString() ?? '';
      final rawSt = (data['docStatus'] ?? data['doc_status'] ?? 'posted')
          .toString()
          .trim()
          .toLowerCase();
      _editDocStatusRaw =
          (rawSt == 'draft' || rawSt == 'approved' || rawSt == 'posted')
              ? rawSt
              : 'posted';
      setState(() => _isDocNoLoading = false);

      // lookups รันแยกอิสระ — provider track loading ตัวเองแล้ว
      await Future.wait([
        incomeProvider.loadMoneyTypes(),
        incomeProvider.loadIncomeTypes(),
      ]);
      if (!mounted) return;

      final prefsData = await prefsFuture;
      token = prefsData.getString("token");
      userId = prefsData.getString("userId");

      unawaited(_checkSetupReadiness());

      final parsed =
          _extractReceiveFromAndDetail(data['detail']?.toString() ?? '');
      _receiveFrom.text = data['partyName']?.toString() ?? parsed.$1;
      final loadedParty = _receiveFrom.text.trim();
      if (loadedParty.isNotEmpty) {
        final payerRows = await _loadPayerPartyRows(forceRefresh: true);
        if (!mounted) return;
        final canon = _canonicalPayerNameFromRows(loadedParty, payerRows);
        if (canon == null) {
          _receiveFrom.text = '';
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showSnack(TransactionUiText.receiveFromStaleEditCleared);
            }
          });
        } else {
          _receiveFrom.text = canon;
        }
      }
      _detail.text = parsed.$2;
      _amount.text = data['amount']?.toString() ?? '';
      _remark.text = data['remark']?.toString() ?? '';
      _bankReference.text = data['bankReference']?.toString() ??
          data['bank_reference']?.toString() ??
          '';
      final rawDate = data['docdate']?.toString();
      if (rawDate != null && rawDate.isNotEmpty) {
        docDate = rawDate;
        final parsedDate = DateTime.tryParse(rawDate);
        if (parsedDate != null && mounted) {
          setState(() => _selectedDocDate = parsedDate);
        }
      }
      final editIncomeType = data['refIncomeType']?.toString() ??
          data['refincometype']?.toString() ??
          '';
      final editBudgetSource = data['refBudgetSource']?.toString() ?? '';
      if (editIncomeType.isNotEmpty) {
        await incomeProvider.loadBudgetSourcesForIncomeType(editIncomeType);
        final sourceMatchesIncomeType = incomeProvider.budgetSource
            .any((row) => row.isNotEmpty && row[0] == editBudgetSource);
        if (sourceMatchesIncomeType) {
          incomeProvider.addBudgetSourceCode(editBudgetSource);
        }
      } else if (editBudgetSource.isNotEmpty) {
        await incomeProvider.loadBudgetSourceContextById(editBudgetSource);
      } else {
        await incomeProvider.loadBudgetSourcesForSelectedIncomeType();
      }
      if (!mounted) return;
      incomeProvider.addMonneyTypeCode(data['refMoneyType']?.toString() ?? '');
      _initialIncomeTypeCode = incomeProvider.incomeTypeCode;
      _initialBudgetSourceCode = incomeProvider.budgetSourceCode;
      _initialMoneyTypeCode = incomeProvider.monneyTypeCode;
      _captureInitialSnapshot();
      _warmPayerPartyCacheInBackground();
      return;
    }

    // ── Add mode ───────────────────────────────────────────────────
    // warm cache เริ่มก่อนทุกอย่าง
    _warmPayerPartyCacheInBackground();

    // lookups + fetchDocNo เริ่มพร้อมกัน — แต่ละกลุ่ม setState ตัวเองเมื่อเสร็จ
    final docDateStr = docDate.split(' ')[0];
    final lookupFuture = () async {
      await Future.wait([
        incomeProvider.loadMoneyTypes(),
        incomeProvider.loadIncomeTypes(),
        incomeProvider.loadAvailableReceiptBooks(),
      ]);
      await incomeProvider.loadBudgetSourcesForSelectedIncomeType();
    }();
    await Future.wait([
      // provider notify ตัวเองเมื่อ isXxxLoading เปลี่ยน — ไม่ต้อง setState ที่นี่
      lookupFuture,
      incomeProvider
          .fetchDocNo(tableName: 'income', docDate: docDateStr)
          .then((docNo) {
        if (!mounted) return;
        if (docNo != null) _docno.text = docNo;
        setState(() => _isDocNoLoading = false);
      }),
    ]);

    if (!mounted) return;

    final prefsData = await prefsFuture;
    token = prefsData.getString("token");
    userId = prefsData.getString("userId");

    unawaited(_checkSetupReadiness());
    _captureInitialSnapshot();
    _warmPayerPartyCacheInBackground();
  }

  void _onIncomeTypeChanged(IncomeProvider provider, String incomeTypeCode) {
    unawaited(provider.loadBudgetSourcesForIncomeType(incomeTypeCode).then((_) {
      if (mounted && !_shouldShowBankReference(provider)) {
        _bankReference.clear();
      }
      _scheduleAutoSave();
    }));
    unawaited(_checkSetupReadiness());
  }

  String _getIncomeTypeNameByCode(IncomeProvider provider, String code) {
    if (code.isEmpty) return '';
    for (final item in provider.incomeType) {
      if (item.length >= 2 && item[0] == code) {
        return item[1];
      }
    }
    return '';
  }

  String _getIncomeTypeCodeById(IncomeProvider provider, String id) {
    if (id.isEmpty) return '';
    for (final item in provider.incomeType) {
      if (item.length >= 3 && item[0] == id) {
        return item[2];
      }
    }
    return '';
  }

  String _selectedMoneyTypeName(IncomeProvider provider) {
    final selected = provider.monneyTypeCode;
    if (selected.isEmpty) return '';
    for (final item in provider.monneyType) {
      if (item.length >= 2 && item[0] == selected) {
        return item[1];
      }
    }
    return '';
  }

  bool _isBankInterestIncomeType(IncomeProvider provider) {
    final code =
        _getIncomeTypeCodeById(provider, provider.incomeTypeCode).toUpperCase();
    return code == 'OB-10' || code == 'OB-12' || code == 'OB-13';
  }

  bool _shouldShowBankReference(IncomeProvider provider) {
    final moneyTypeName = _selectedMoneyTypeName(provider);
    final pocket = MoneyTypePocket.classify(name: moneyTypeName);
    return pocket == MoneyTypePocket.bank ||
        _isBankInterestIncomeType(provider);
  }

  Widget _buildBankReferenceNotice(AppColors c) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              TransactionUiText.incomeBankReferenceSectionHint,
              style: _pageBodyStyle(c, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  bool _isDepositRegisterIncomeType(IncomeProvider provider) {
    final selected = provider.incomeTypeCode;
    if (selected.isEmpty) return false;
    final code = _getIncomeTypeCodeById(provider, selected);
    if (code.isNotEmpty) {
      return IncomeMoneyDomainRule.isDepositRegisterCode(code);
    }
    return IncomeMoneyDomainRule.isDepositRegisterLookupId(selected);
  }

  void _clearInput() {
    _docno.text = '';
    _receiveFrom.text = '';
    _detail.text = '';
    _amount.text = '';
    _remark.text = '';
    _bankReference.text = '';
    _receiptNo.clear();
    _issueReceipt = false;
    _receiptBookId = '';
    _receiptNextHint = '';
    _autoSaveDebounce?.cancel();
    _autoDraftLocalId = null;
    _lastAutoDraftSignature = null;
    _autoDraftMessage = TransactionUiText.autoDraftWaiting;
  }

  Future<bool> _checkDataBeforeInsert() async {
    if (_docno.text.trim().isEmpty) {
      _showSnack(TransactionUiText.incomeDocNoCreateFailed);
      return false;
    }
    if (incomeProvider.incomeTypeCode == "") {
      _showSnack(TransactionUiText.selectIncomeType);
      return false;
    }
    if (_isDepositRegisterIncomeType(incomeProvider)) {
      _showSnack(TransactionUiText.incomeDepositRegisterTypeNotAllowed);
      return false;
    }
    if (incomeProvider.incomeTypeCode.isNotEmpty &&
        incomeProvider.budgetSource.isEmpty) {
      await _promptNavigateToFixIncomeTypeBudgetSource();
      return false;
    }
    if (incomeProvider.budgetSourceCode == "") {
      if (incomeProvider.incomeTypeCode.isNotEmpty) {
        await _promptNavigateToFixIncomeTypeBudgetSource();
      } else {
        _showSnack(TransactionUiText.selectBudgetSource);
      }
      return false;
    }
    if (_receiveFrom.text.trim().isEmpty) {
      _showSnack(TransactionUiText.incomeSpecifyReceiveFrom);
      return false;
    }
    if (!_isEditMode && _issueReceipt) {
      if (_receiptBookId.isEmpty || _receiptNo.text.trim().isEmpty) {
        _showSnack(TransactionUiText.incomeReceiptFieldsIncomplete);
        return false;
      }
      final receiptError = _receiptNoBookValidationError(_receiptNo.text);
      if (receiptError != null) {
        _showSnack(receiptError);
        return false;
      }
    }
    final payerRows = await _loadPayerPartyRows(forceRefresh: true);
    if (!mounted) return false;
    if (payerRows.isEmpty) {
      await _promptNavigateToAddPayerParty();
      return false;
    }
    final partyCanon =
        _canonicalPayerNameFromRows(_receiveFrom.text, payerRows);
    if (partyCanon == null) {
      _showSnack(TransactionUiText.receiveFromMustBeRegistered);
      return false;
    }
    if (_receiveFrom.text.trim() != partyCanon) {
      _receiveFrom.text = partyCanon;
    }
    if (_amount.text.isEmpty) {
      _showSnack(TransactionUiText.fillAmount);
      return false;
    }
    if ((double.tryParse(_amount.text.replaceAll(',', '')) ?? 0) <= 0) {
      _showSnack(TransactionUiText.amountMustPositive);
      return false;
    }
    return true;
  }

  bool _isFormReady(IncomeProvider p) {
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    var ok = p.incomeTypeCode.isNotEmpty &&
        !_isDepositRegisterIncomeType(p) &&
        p.budgetSourceCode.isNotEmpty &&
        _receiveFrom.text.trim().isNotEmpty &&
        amount > 0;
    if (ok && !_isEditMode && _issueReceipt) {
      ok = _receiptBookId.isNotEmpty &&
          _receiptNo.text.trim().isNotEmpty &&
          _receiptNoBookValidationError(_receiptNo.text) == null;
    }
    return ok;
  }

  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
    _scheduleAutoSave();
  }

  String _buildMissingRequiredText(IncomeProvider p) {
    final missing = <String>[];
    if (p.incomeTypeCode.isEmpty) {
      missing.add(TransactionUiText.incomeMissingFieldCategory);
    } else if (_isDepositRegisterIncomeType(p)) {
      missing.add(TransactionUiText.incomeDepositRegisterTypeNotAllowed);
    }
    if (p.incomeTypeCode.isNotEmpty && p.budgetSourceCode.isEmpty) {
      missing.add(TransactionUiText.incomeMissingFieldBudget);
    }
    if (_receiveFrom.text.trim().isEmpty) {
      missing.add(TransactionUiText.incomeMissingFieldReceiveFrom);
    }
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      missing.add(TransactionUiText.incomeMissingFieldAmount);
    }
    if (!_isEditMode && _issueReceipt) {
      if (_receiptBookId.isEmpty || _receiptNo.text.trim().isEmpty) {
        missing.add(TransactionUiText.incomeReceiptBookLabel);
      }
    }
    if (missing.isEmpty) return TransactionUiText.incomeReadyToSave;
    return '${TransactionUiText.incomeMissingRequiredPrefix}${missing.join(', ')}';
  }

  void _captureInitialSnapshot() {
    _initialDocNo = _docno.text.trim();
    _initialReceiveFrom = _receiveFrom.text.trim();
    _initialDetail = _detail.text.trim();
    _initialAmount = _amount.text.trim();
    _initialRemark = _remark.text.trim();
    _initialBankReference = _bankReference.text.trim();
    _initialDocDate = docDate.trim();
  }

  bool _hasUnsavedChanges() {
    final currentDocNo = _docno.text.trim();
    final currentReceiveFrom = _receiveFrom.text.trim();
    final currentDetail = _detail.text.trim();
    final currentAmount = _amount.text.trim();
    final currentRemark = _remark.text.trim();
    final currentBankReference = _bankReference.text.trim();
    final currentDocDate = docDate.trim();

    final currentIncomeTypeCode = incomeProvider.incomeTypeCode.trim();
    final currentBudgetSourceCode = incomeProvider.budgetSourceCode.trim();
    final currentMoneyTypeCode = incomeProvider.monneyTypeCode.trim();

    if (_isEditMode) {
      return currentDocNo != _initialDocNo ||
          currentReceiveFrom != _initialReceiveFrom ||
          currentDetail != _initialDetail ||
          currentAmount != _initialAmount ||
          currentRemark != _initialRemark ||
          currentBankReference != _initialBankReference ||
          currentDocDate != _initialDocDate ||
          currentIncomeTypeCode != _initialIncomeTypeCode ||
          currentBudgetSourceCode != _initialBudgetSourceCode ||
          currentMoneyTypeCode != _initialMoneyTypeCode;
    }

    return currentDocNo.isNotEmpty ||
        currentReceiveFrom.isNotEmpty ||
        currentDetail.isNotEmpty ||
        currentAmount.isNotEmpty ||
        currentRemark.isNotEmpty ||
        currentBankReference.isNotEmpty ||
        currentIncomeTypeCode.isNotEmpty ||
        currentBudgetSourceCode.isNotEmpty ||
        currentMoneyTypeCode.isNotEmpty ||
        _issueReceipt ||
        _receiptBookId.isNotEmpty ||
        _receiptNo.text.trim().isNotEmpty;
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
        title: TransactionUiText.incomeUnsavedLeaveTitle,
        message: TransactionUiText.incomeUnsavedLeaveBody,
        cancelText: TransactionUiText.incomeUnsavedStay,
        confirmText: TransactionUiText.incomeUnsavedLeaveWithoutSave,
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
        title: TransactionUiText.incomeResetTitle,
        message: TransactionUiText.incomeResetBody,
        cancelText: TransactionUiText.incomeResetCancel,
        confirmText: TransactionUiText.incomeResetConfirm,
        confirmColor: AppColors.of(dialogContext).navy,
      ),
    );
    if (shouldReset != true || !mounted) return;

    incomeProvider.addIncomeTypeCode('');
    incomeProvider.addBudgetSourceCode('');
    incomeProvider.addMonneyTypeCode('');
    _receiveFrom.clear();
    _detail.clear();
    _amount.clear();
    _remark.clear();
    _receiptNo.clear();
    _issueReceipt = false;
    _receiptBookId = '';
    _receiptNextHint = '';

    final now = DateTime.now();
    setState(() {
      _selectedDocDate = now;
      docDate = now.toString();
    });

    final docDateParts = docDate.split(' ');
    final docNo = await incomeProvider.fetchDocNo(
      tableName: 'income',
      docDate: docDateParts[0],
    );
    if (!mounted) return;
    _docno.text = docNo ?? '';
    _captureInitialSnapshot();
    _showSnack(TransactionUiText.incomeResetDone);
  }

  Future<void> _refreshDocNoForSelectedDate() async {
    final selectedDate = _selectedDocDate.toIso8601String().split('T').first;
    final docNo = await incomeProvider.fetchDocNo(
      tableName: 'income',
      docDate: selectedDate,
    );
    if (!mounted || docNo == null || docNo.isEmpty) return;
    _docno.text = docNo;
  }

  static bool _partyRowIsActive(Map<String, dynamic> row) {
    return row['isactive'] == true || row['isactive']?.toString() == '1';
  }

  /// รับเงินจากผู้จ่ายได้ — ไม่รวมเฉพาะผู้รับ
  static bool _partyRowCanActAsPayer(Map<String, dynamic> row) {
    final role = (row['role'] ?? 'both').toString().toLowerCase().trim();
    return role == 'payer' || role == 'both';
  }

  /// โหลดรายชื่อผู้จ่ายจาก SQLite เสมอ — ซิงก์จากเซิร์ฟเวอร์ทำเบื้องหลังผ่าน repository
  Future<List<Map<String, dynamic>>> _loadPayerPartyRows({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _payerRowsCache != null &&
        _payerRowsCacheAt != null &&
        now.difference(_payerRowsCacheAt!) < _payerRowsCacheTtl) {
      return _payerRowsCache!;
    }

    if (!forceRefresh && _payerRowsInflight != null) {
      return _payerRowsInflight!;
    }

    if (forceRefresh) {
      _payerRowsInflight = null;
      _invalidatePayerRowsCache();
    }

    final work = _loadPayerPartyRowsImpl();
    if (!forceRefresh) {
      _payerRowsInflight = work;
    }
    try {
      return await work;
    } finally {
      if (!forceRefresh && identical(_payerRowsInflight, work)) {
        _payerRowsInflight = null;
      }
    }
  }

  static List<Map<String, dynamic>> _partyRowsFromPartyOptions(
    List<List<String>> options,
  ) {
    return options
        .map(
          (e) => <String, dynamic>{
            'id': e[0],
            'name': e[1],
            'role': 'both',
            'isactive': true,
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadPayerPartyRowsImpl() async {
    final gen = _payerLoadGeneration;
    if (!mounted) return [];

    var raw = await incomeProvider.loadPayerPartyRowsLocalForPicker();
    if (!mounted) return [];
    if (raw.isEmpty) {
      await incomeProvider.loadPartyOptionsFromLocalIncome();
      if (!mounted) return [];
      raw = _partyRowsFromPartyOptions(incomeProvider.partyOptions);
    }

    if (raw.isEmpty) {
      await incomeProvider.loadPartyOptions();
      if (!mounted) return [];
      raw = _partyRowsFromPartyOptions(incomeProvider.partyOptions);
    }

    unawaited(incomeProvider.refreshPartyMasterCacheFromServer());

    final filtered = _filterPayerRowsActive(raw);
    if (!mounted) return filtered;
    if (gen == _payerLoadGeneration) {
      _payerRowsCache = filtered;
      _payerRowsCacheAt = DateTime.now();
    }
    return filtered;
  }

  static String? _canonicalPayerNameFromRows(
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

  Future<String?> _refPartyIdForSave() async {
    final name = _receiveFrom.text.trim();
    if (name.isEmpty) return null;
    final payerRows = await _loadPayerPartyRows(forceRefresh: true);
    if (!mounted) return null;
    final canon = _canonicalPayerNameFromRows(name, payerRows);
    if (canon == null) return null;
    for (final row in payerRows) {
      if ((row['name']?.toString().trim() ?? '') == canon) {
        return row['id']?.toString();
      }
    }
    return null;
  }

  Future<void> _showReceiptPrintSummary() async {
    if (!mounted) return;
    final bookLabel = _receiptBookLabelForId(_receiptBookId);
    final body = StringBuffer()
      ..writeln('${TransactionUiText.docNumber}: ${_docno.text.trim()}')
      ..writeln(
          '${TransactionUiText.date}: ${ThaiDateFormatter.format(_selectedDocDate)}')
      ..writeln('${TransactionUiText.incomeReceiptBookLabel}: $bookLabel')
      ..writeln(
          '${TransactionUiText.incomeReceiptNoLabel}: ${_receiptNo.text.trim()}')
      ..writeln('${TransactionUiText.receiveFrom}: ${_receiveFrom.text.trim()}')
      ..writeln(
          '${TransactionUiText.amount}: ${_amount.text.trim()} ${TransactionUiText.baht}')
      ..writeln('${TransactionUiText.detail}: ${_detail.text.trim()}');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = AppColors.of(sheetContext);
        return SafeArea(
          child: AdaptiveContentSheet(
            title: TransactionUiText.incomeReceiptPrintCopyTitle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp16,
                0,
                AppTheme.sp16,
                AppTheme.sp16,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(
                      body.toString(),
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        color: c.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton.primary(
                        label: TransactionUiText.ok,
                        fullWidth: false,
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _receiptBookLabelForId(String id) {
    if (id.isEmpty) return '';
    for (final row in incomeProvider.receiptBookOptions) {
      if (row.isNotEmpty && row[0] == id) return row.length >= 2 ? row[1] : id;
    }
    return id;
  }

  String _composeDetailForSave() {
    final detail = _detail.text.trim();
    return detail;
  }

  (String, String) _extractReceiveFromAndDetail(String rawDetail) {
    final normalized = rawDetail.trim();
    if (normalized.isEmpty) return ('', '');
    final lines = normalized.split('\n');
    if (lines.isEmpty) return ('', normalized);
    final firstLine = lines.first.trim();
    final prefix = TransactionUiText.incomeSavedDetailReceiveFromPrefix;
    if (!firstLine.startsWith(prefix)) return ('', normalized);
    final receiveFrom = firstLine.replaceFirst(prefix, '').trim();
    final detail = lines.skip(1).join('\n').trim();
    return (receiveFrom, detail);
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

  /// ไม่มีผู้จ่ายที่เลือกได้ (เช่น ตอนกดบันทึก) — แจ้งเตือนและให้เปิดหน้าจัดการผู้รับ/ผู้จ่าย
  Future<void> _promptNavigateToAddPayerParty() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => NoPayerPartyPromptDialog(
        onGoAddParty: () {
          if (mounted) _openPartyManagementPage();
        },
      ),
    );
  }

  Future<void> _promptNavigateToFixIncomeTypeBudgetSource() async {
    if (!mounted) return;
    final shouldGo = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmDialog(
        isDestructive: false,
        title: TransactionUiText.incomeBudgetEmptyDialogTitle,
        message: TransactionUiText.incomeBudgetEmptyDialogBody,
        cancelText: TransactionUiText.cancel,
        confirmText: TransactionUiText.incomeBudgetEmptyDialogConfirm,
        confirmColor: AppColors.of(dialogContext).navy,
      ),
    );
    if (shouldGo == true && mounted) {
      await _openIncomeTypePage(
        initialIncomeTypeId: incomeProvider.incomeTypeCode,
      );
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
          _invalidatePayerRowsCache();
          unawaited(_checkSetupReadiness());
        }
      }),
    );
  }

  Future<void> _openReceiptBookRegisterPage() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const RegisterPage(initialTabIndex: 5),
      ),
    );
    if (!mounted) return;
    await incomeProvider.loadAvailableReceiptBooks();
    await _refreshReceiptNextHint();
    if (!mounted) return;
    final hasAvailableBooks = incomeProvider.receiptBookOptions.isNotEmpty;
    _showSnack(
      hasAvailableBooks
          ? TransactionUiText.incomeReceiptBooksRefreshedReady
          : TransactionUiText.incomeReceiptBooksRefreshedStillEmpty,
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
