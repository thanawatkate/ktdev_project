import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/lookup_item_local_data_source.dart';
import 'package:saccm/core/local_data_source/member_local_data_source.dart';
import 'package:saccm/features/loan/data/repositories/loan_repository_offline.dart';
import 'package:saccm/features/loan/presentation/providers/loan_provider.dart';
import 'package:saccm/features/member/presentation/pages/member_page.dart';
import 'package:saccm/features/member/presentation/providers/member_provider.dart';
import 'package:saccm/widgets/dialog/form_leave_confirm_dialog.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoanAddPage extends StatefulWidget {
  const LoanAddPage({
    super.key,
    this.initialData,
    this.embeddedInHome = false,
  });

  final Map<String, dynamic>? initialData;
  final bool embeddedInHome;

  @override
  State<LoanAddPage> createState() => _LoanAddPageState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _LoanAddPageState extends State<LoanAddPage> {
  static const String _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;
  final _docnoCtrl = TextEditingController();
  final _borrowerCtrl = TextEditingController();
  final _openingOutstandingCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  final _openingFocus = FocusNode();
  final _remarkFocus = FocusNode();
  final List<_LoanSubRowEdit> _subRows = [];

  DateTime _selectedLoanDate = DateTime.now();
  DateTime _selectedDueDate = DateTime.now();
  late String _loanDate = DateTime.now().toIso8601String();
  late String _dueDate = DateTime.now().toIso8601String();
  bool get _isEditMode => widget.initialData != null;
  bool _isHandlingBackNavigation = false;
  String _initialDocNo = '';
  String _initialBorrower = '';
  String _initialOpeningOutstanding = '';
  String _initialRemark = '';
  String _initialLoanDate = '';
  String _initialDueDate = '';
  String _initialSubsSnapshot = '';
  String _refMemberId = '';
  String _initialRefMemberId = '';

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _docnoCtrl.text = data['docno']?.toString() ?? '';
      _refMemberId =
          (data['ref_member'] ?? data['refMember'])?.toString().trim() ?? '';
      _borrowerCtrl.text = data['borrower']?.toString() ?? '';
      final loanDateRaw = data['loandate']?.toString();
      if (loanDateRaw != null && loanDateRaw.isNotEmpty) {
        _loanDate = loanDateRaw;
        final parsedDate = DateTime.tryParse(loanDateRaw);
        if (parsedDate != null) {
          _selectedLoanDate = parsedDate;
        }
      }
      final dueDateRaw = data['duedate']?.toString();
      if (dueDateRaw != null && dueDateRaw.isNotEmpty) {
        _dueDate = dueDateRaw;
        final parsedDueDate = DateTime.tryParse(dueDateRaw);
        if (parsedDueDate != null) {
          _selectedDueDate = parsedDueDate;
        }
      } else {
        _selectedDueDate = _selectedLoanDate;
        _dueDate = _selectedLoanDate.toIso8601String();
      }
      final o = data['opening_outstanding'];
      _openingOutstandingCtrl.text =
          o == null ? '' : (o is num ? o.toString() : o.toString());
      _remarkCtrl.text = data['remark']?.toString() ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _syncBorrowerFieldWithMemberRegistry();
        final loanId = data['id']?.toString() ?? '';
        await _loadLoanSubsForEdit(loanId, legacyPrincipal: data['amount']);
        if (mounted) _captureInitialSnapshot();
      });
    } else {
      _bindDefaultSubRow();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final provider = Provider.of<LoanProvider?>(context, listen: false);
        await provider?.loadLoanList();
        final now = DateTime.now().toIso8601String().split('T').first;
        final docno = await provider?.fetchDocNo(
          tableName: 'loan',
          docDate: now,
        );
        if (!mounted || docno == null) return;
        setState(() {
          _docnoCtrl.text = docno;
          _captureInitialSnapshot();
        });
      });
    }
    _docnoCtrl.addListener(_onAnyFieldChanged);
    _borrowerCtrl.addListener(_onAnyFieldChanged);
    _openingOutstandingCtrl.addListener(_onAnyFieldChanged);
    _remarkCtrl.addListener(_onAnyFieldChanged);
  }

  void _bindDefaultSubRow() {
    if (_subRows.isNotEmpty) return;
    final r = _LoanSubRowEdit();
    r.amountCtrl.addListener(_onAnyFieldChanged);
    r.remarkCtrl.addListener(_onAnyFieldChanged);
    _subRows.add(r);
  }

  Future<void> _loadLoanSubsForEdit(
    String loanId, {
    dynamic legacyPrincipal,
  }) async {
    final repo = ServiceLocator.instance.get<LoanRepository>();
    final persisted = await repo.getLoanSubRows(loanId);
    if (!mounted) return;

    final built = <_LoanSubRowEdit>[];
    if (persisted.isEmpty) {
      final legacy = legacyPrincipal == null
          ? 0.0
          : (legacyPrincipal is num
              ? legacyPrincipal.toDouble()
              : double.tryParse(legacyPrincipal.toString()) ?? 0);
      if (legacy > 0) {
        final r = _LoanSubRowEdit();
        r.amountCtrl.text = legacy.toString();
        r.amountCtrl.addListener(_onAnyFieldChanged);
        r.remarkCtrl.addListener(_onAnyFieldChanged);
        built.add(r);
      } else {
        final r = _LoanSubRowEdit();
        r.amountCtrl.addListener(_onAnyFieldChanged);
        r.remarkCtrl.addListener(_onAnyFieldChanged);
        built.add(r);
      }
    } else {
      for (final s in persisted) {
        final label = await _incomeTypeLabel(s.refFundCategory);
        if (!mounted) return;
        final r = _LoanSubRowEdit(
          refFundCategoryId: s.refFundCategory,
          categoryLabel: label,
          amountText: s.amount.toString(),
          remarkText: s.remark,
        );
        r.amountCtrl.addListener(_onAnyFieldChanged);
        r.remarkCtrl.addListener(_onAnyFieldChanged);
        built.add(r);
      }
    }

    setState(() {
      for (final r in _subRows) {
        r.dispose();
      }
      _subRows
        ..clear()
        ..addAll(built);
    });
  }

  Future<String> _incomeTypeLabel(String id) async {
    if (id.isEmpty) return '';
    final ds = ServiceLocator.instance.get<IncomeTypeLocalDataSource>();
    final types = await ds.getAllIncomeTypes();
    for (final t in types) {
      if (t.id == id) return _formatIncomeTypeLabel(t);
    }
    return id;
  }

  String _formatMemberLabel(MemberModel m) {
    final code = m.code.trim();
    final name = m.name.trim();
    if (name.isEmpty) return code;
    if (code.isNotEmpty) return '$code — $name';
    return name;
  }

  String _formatIncomeTypeLabel(LookupItemModel t) {
    final code = t.code.trim();
    final name = t.name.trim();
    if (name.isEmpty) return code;
    if (code.isNotEmpty) return '$code — $name';
    return name;
  }

  Future<List<AppDropdownItem<String>>> _loadMemberLookupItems() async {
    final ds = ServiceLocator.instance.get<MemberLocalDataSource>();
    final rows = await ds.getAllMembers();
    return rows
        .map(
          (m) => AppDropdownItem<String>(
            value: m.id,
            label: _formatMemberLabel(m),
          ),
        )
        .toList();
  }

  Future<List<AppDropdownItem<String>>> _loadIncomeTypeLookupItems() async {
    final ds = ServiceLocator.instance.get<IncomeTypeLocalDataSource>();
    final rows = await ds.getAllIncomeTypes();
    return rows
        .map(
          (t) => AppDropdownItem<String>(
            value: t.id,
            label: _formatIncomeTypeLabel(t),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _docnoCtrl.removeListener(_onAnyFieldChanged);
    _borrowerCtrl.removeListener(_onAnyFieldChanged);
    _openingOutstandingCtrl.removeListener(_onAnyFieldChanged);
    _remarkCtrl.removeListener(_onAnyFieldChanged);
    _docnoCtrl.dispose();
    _borrowerCtrl.dispose();
    _openingOutstandingCtrl.dispose();
    _remarkCtrl.dispose();
    for (final r in _subRows) {
      r.dispose();
    }
    _subRows.clear();
    _openingFocus.dispose();
    _remarkFocus.dispose();
    super.dispose();
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
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: c.loanAmber,
                        iconBgColor: c.iconBgLoan,
                        title: _isEditMode
                            ? TransactionUiText.editLoanItem
                            : TransactionUiText.addLoanItem,
                        subtitle: TransactionUiText.reviewBeforeSave,
                        quickHint: TransactionUiText.loanRequiredBeforeSaveHint,
                        hintAccentColor: c.loanAmber,
                        hintBorderColor: c.cardBorder,
                        textPrimaryColor: c.textPrimary,
                        showQuickHint: false,
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      _buildFormCard(c),
                      const SizedBox(height: AppTheme.sp16),
                      _buildActionBar(c),
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

  PreferredSizeWidget _buildAppBar(AppColors c) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: c.cardWhite,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: c.textPrimary),
        onPressed: _handleBackNavigation,
      ),
      title: widget.embeddedInHome
          ? const SizedBox.shrink()
          : Text(
              _isEditMode
                  ? TransactionUiText.editLoanItem
                  : TransactionUiText.addLoanItem,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
      actions: [
        Consumer<LoanProvider?>(
          builder: (_, loanProvider, __) {
            final isReady = _isFormReady();
            final isLoading = loanProvider?.isLoading ?? false;
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
                    tooltip: TransactionUiText.loanPageGuideTitle,
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
                    isLoading: isLoading,
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
              _buildSchemaSectionHeader(
                c,
                icon: Icons.table_rows_outlined,
                title: TransactionUiText.loanSchemaSectionLoanTitle,
                subtitle: TransactionUiText.loanSchemaSectionLoanSubtitle,
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
                      child: AppDateInput(
                        initialValue: _selectedLoanDate,
                        label: TransactionUiText.date,
                        dateFormat: AppDateFormat.thaiBuddhist,
                        onChanged: (d) {
                          if (d == null) return;
                          setState(() {
                            _selectedLoanDate = d;
                            _loanDate = d.toIso8601String();
                          });
                          if (!_isEditMode) {
                            _refreshDocNoForSelectedDate();
                          }
                        },
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppDateInput(
                        initialValue: _selectedDueDate,
                        label: TransactionUiText.loanDueDate,
                        helperText: TransactionUiText.loanDueDateHelper,
                        dateFormat: AppDateFormat.thaiBuddhist,
                        onChanged: (d) {
                          if (d == null) return;
                          setState(() {
                            _selectedDueDate = d;
                            _dueDate = d.toIso8601String();
                          });
                        },
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.docNumber,
                        hint: TransactionUiText.autoGenerated,
                        helperText: TransactionUiText.loanDocNoAutoHelper,
                        readOnly: true,
                        controller: _docnoCtrl,
                        prefixIcon: const Icon(Icons.tag_rounded),
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount >= 4 ? 2 : 1,
                      child: _buildBorrowerField(),
                    ),
                    if (!_isEditMode)
                      _ResponsiveFormField(
                        span: columnCount,
                        child: _buildOutstandingBorrowerHint(c),
                      ),
                    _ResponsiveFormField(
                      child: _buildPrincipalSummaryBox(c),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.loanOpeningOutstanding,
                        hint: '0.00',
                        helperText:
                            TransactionUiText.loanOpeningOutstandingHint,
                        controller: _openingOutstandingCtrl,
                        focusNode: _openingFocus,
                        action: const AppInputAction.number(allowDecimal: true),
                        textAlign: TextAlign.right,
                        prefixIcon: const Icon(Icons.history_rounded),
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount,
                      child: AppInput(
                        label: TransactionUiText.remark,
                        hint: TransactionUiText.remarkHint,
                        controller: _remarkCtrl,
                        focusNode: _remarkFocus,
                        minLines: 2,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              _buildSchemaSectionHeader(
                c,
                icon: Icons.view_list_outlined,
                title: TransactionUiText.loanSchemaSectionLoanSubTitle,
                subtitle: TransactionUiText.loanSchemaSectionLoanSubSubtitle,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: _buildLoanSubRowsSection(
                  c,
                  contentWidth: contentWidth,
                  columnCount: columnCount,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBorrowerField() {
    return ListenableBuilder(
      listenable: _borrowerCtrl,
      builder: (context, _) {
        final borrower = _borrowerCtrl.text.trim();
        return AppLookupPickerField<String>(
          label: TransactionUiText.loanBorrower,
          hint: TransactionUiText.loanBorrowerHint,
          required: true,
          helperText: TransactionUiText.loanBorrowerHelper,
          value: _refMemberId.isEmpty ? null : _refMemberId,
          displayLabel: borrower.isEmpty ? null : borrower,
          clearable: false,
          pickerTitle: TransactionUiText.loanBorrowerPickerTitle,
          searchHint: TransactionUiText.loanBorrowerPickerSearchHint,
          loadingText: TransactionUiText.loanBorrowerPickerLoading,
          emptyText: TransactionUiText.loanBorrowerNoMembersBody,
          emptyActionLabel: TransactionUiText.loanBorrowerGoRegister,
          onEmptyAction: _openMemberRegisterPage,
          loadItems: _loadMemberLookupItems,
          onChanged: (v) async {
            final memberId = v?.trim() ?? '';
            if (memberId.isEmpty) return;
            final items = await _loadMemberLookupItems();
            final selected = items.cast<AppDropdownItem<String>?>().firstWhere(
                  (item) => item?.value == memberId,
                  orElse: () => null,
                );
            if (!mounted || selected == null) return;
            setState(() {
              _refMemberId = memberId;
              _borrowerCtrl.text = selected.label;
            });
          },
          prefixIcon: const Icon(Icons.person_outline_rounded),
        );
      },
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

  Widget _buildSchemaSectionHeader(
    AppColors c, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp16,
        AppTheme.sp12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              subtitle,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 12,
                height: 1.35,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _principalFromSubs {
    var s = 0.0;
    for (final r in _subRows) {
      s += _parseAmountText(r.amountCtrl.text);
    }
    return s;
  }

  double _parseAmountText(String value) =>
      double.tryParse(value.replaceAll(',', '').trim()) ?? 0;

  String _serializeSubs() {
    final parts = <String>[];
    for (final r in _subRows) {
      parts.add(
        '${r.refFundCategoryId.trim()}|${r.amountCtrl.text.trim()}|${r.remarkCtrl.text.trim()}',
      );
    }
    return parts.join(';');
  }

  Widget _buildPrincipalSummaryBox(AppColors c) {
    final p = _principalFromSubs;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp12,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TransactionUiText.loanPrincipalDocAmount,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.sp8),
          Text(
            p <= 0 ? '-' : p.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.loanAmber,
            ),
          ),
          const SizedBox(height: AppTheme.sp4),
          Text(
            TransactionUiText.loanPrincipalAmountHelper,
            style: _pageBodyStyle(c, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanSubRowsSection(
    AppColors c, {
    required double contentWidth,
    required int columnCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_subRows.isNotEmpty)
          _buildLoanSubFields(
            c,
            0,
            contentWidth: contentWidth,
            columnCount: columnCount,
          ),
        if (_subRows.length > 1) ...[
          const SizedBox(height: AppTheme.sp12),
          Text(
            TransactionUiText.loanSubAdditionalRowsTitle,
            style: TextStyle(
              color: c.textSecondary,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppTheme.sp8),
          ...List.generate(
            _subRows.length - 1,
            (offset) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sp8),
              child: _buildOneSubRow(
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
            onPressed: _addSubRow,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text(
              TransactionUiText.loanSubAddRow,
              style: const TextStyle(fontFamily: _fontFamily),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOneSubRow(
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
                TransactionUiText.loanSubRowTitle(index + 1),
                style: TextStyle(
                  color: c.textPrimary,
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              tooltip: TransactionUiText.loanSubRemoveRow,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, color: scheme.error),
              onPressed: () => _removeSubRow(index),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        _buildLoanSubFields(
          c,
          index,
          contentWidth: contentWidth,
          columnCount: columnCount,
        ),
      ],
    );
  }

  Widget _buildLoanSubFields(
    AppColors c,
    int index, {
    required double contentWidth,
    required int columnCount,
  }) {
    final row = _subRows[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _responsiveFieldGrid(
          contentWidth,
          columnCount: columnCount,
          fields: [
            _ResponsiveFormField(
              span: columnCount >= 4 ? 2 : 1,
              child: _buildLoanSubCategoryField(index),
            ),
            _ResponsiveFormField(
              child: AppInput(
                label: TransactionUiText.loanSubAmount,
                hint: '0.00',
                controller: row.amountCtrl,
                action: const AppInputAction.number(allowDecimal: true),
                textAlign: TextAlign.right,
                prefixIcon: const Icon(Icons.attach_money_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        _responsiveFieldGrid(
          contentWidth,
          columnCount: columnCount,
          fields: [
            _ResponsiveFormField(
              span: columnCount,
              child: AppInput(
                label: TransactionUiText.loanSubRemark,
                hint: TransactionUiText.remarkHint,
                controller: row.remarkCtrl,
                minLines: 1,
                maxLines: 3,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoanSubCategoryField(int index) {
    final row = _subRows[index];
    return AppLookupPickerField<String>(
      label: TransactionUiText.loanSubPickCategory,
      hint: TransactionUiText.loanSubPickCategoryHint,
      value: row.refFundCategoryId.trim().isEmpty
          ? null
          : row.refFundCategoryId.trim(),
      displayLabel:
          row.categoryCtrl.text.trim().isEmpty ? null : row.categoryCtrl.text,
      clearable: false,
      required: _parseAmountText(row.amountCtrl.text) > 0,
      pickerTitle: TransactionUiText.loanSubPickerTitle,
      searchHint: TransactionUiText.loanSubPickerSearchHint,
      loadingText: TransactionUiText.loanSubPickerLoading,
      emptyText: TransactionUiText.loanSubPickerEmpty,
      loadItems: _loadIncomeTypeLookupItems,
      onChanged: (v) async {
        final id = v?.trim() ?? '';
        if (id.isEmpty) return;
        final items = await _loadIncomeTypeLookupItems();
        final selected = items.cast<AppDropdownItem<String>?>().firstWhere(
              (item) => item?.value == id,
              orElse: () => null,
            );
        if (!mounted || selected == null) return;
        setState(() {
          row.refFundCategoryId = id;
          row.categoryLabel = selected.label;
          row.categoryCtrl.text = selected.label;
        });
      },
      prefixIcon: const Icon(Icons.category_outlined),
    );
  }

  void _addSubRow() {
    final r = _LoanSubRowEdit();
    r.amountCtrl.addListener(_onAnyFieldChanged);
    r.remarkCtrl.addListener(_onAnyFieldChanged);
    setState(() => _subRows.add(r));
  }

  void _removeSubRow(int index) {
    if (_subRows.length <= 1) return;
    setState(() {
      final r = _subRows.removeAt(index);
      r.dispose();
    });
  }

  Listenable _loanFormListenable() {
    final parts = <Listenable>[
      _docnoCtrl,
      _borrowerCtrl,
      _openingOutstandingCtrl,
      _remarkCtrl,
    ];
    for (final r in _subRows) {
      parts.add(r.categoryCtrl);
      parts.add(r.amountCtrl);
      parts.add(r.remarkCtrl);
    }
    return Listenable.merge(parts);
  }

  bool _subsMissingCategoryForPositiveAmount() {
    for (final r in _subRows) {
      final a = double.tryParse(r.amountCtrl.text.replaceAll(',', '')) ?? 0;
      if (a > 0 && r.refFundCategoryId.trim().isEmpty) return true;
    }
    return false;
  }

  List<LoanSubLineInput> _collectSubLinesForSave() {
    final out = <LoanSubLineInput>[];
    for (final r in _subRows) {
      out.add(
        LoanSubLineInput(
          refFundCategory: r.refFundCategoryId.trim(),
          amount: r.amountCtrl.text.trim().replaceAll(',', ''),
          remark: r.remarkCtrl.text.trim(),
        ),
      );
    }
    return out;
  }

  Widget _buildActionBar(AppColors c) {
    return ListenableBuilder(
      listenable: _loanFormListenable(),
      builder: (_, __) {
        final docPrincipal = _principalFromSubs;
        final opening =
            double.tryParse(_openingOutstandingCtrl.text.replaceAll(',', '')) ??
                0.0;
        final totalPrincipal = docPrincipal + opening;
        final loanProvider = Provider.of<LoanProvider?>(context);
        final isReady = _isFormReady();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSaveReadinessHint(c, isReady),
            const SizedBox(height: AppTheme.sp8),
            TransactionSummaryActions(
              totalAmount: totalPrincipal,
              totalLabel: TransactionUiText.totalAmount,
              amountColor: c.loanAmber,
              cardColor: c.cardWhite,
              borderColor: c.cardBorder,
              textSecondaryColor: c.textSecondary,
              currencyLabel: TransactionUiText.baht,
              saveLabel: _isEditMode
                  ? TransactionUiText.saveEdit
                  : TransactionUiText.save,
              isSaving: loanProvider?.isLoading ?? false,
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

  Future<void> _onSave() async {
    final refMember = _refMemberId.trim();
    final docPrincipal = _principalFromSubs;
    final openingText = _openingOutstandingCtrl.text.trim().replaceAll(',', '');
    final openingOutstanding = double.tryParse(openingText) ?? 0;
    final subLines = _collectSubLinesForSave();

    if (refMember.isEmpty) {
      _showSnack(TransactionUiText.fillBorrower);
      return;
    }
    if (docPrincipal <= 0 && openingOutstanding <= 0) {
      _showSnack(TransactionUiText.loanSubNeedPrincipalOrOpening);
      return;
    }
    if (_subsMissingCategoryForPositiveAmount()) {
      _showSnack(TransactionUiText.loanSubNeedCategory);
      return;
    }
    if (_selectedDueDate.isBefore(
      DateTime(
        _selectedLoanDate.year,
        _selectedLoanDate.month,
        _selectedLoanDate.day,
      ),
    )) {
      _showSnack(TransactionUiText.loanDueDateMustNotBeforeLoanDate);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (!mounted) return;

    final provider = Provider.of<LoanProvider?>(context, listen: false);
    if (provider == null) {
      _showSnack(TransactionUiText.providerNotFound);
      return;
    }
    if (!_isEditMode) {
      final activeOutstanding =
          await provider.findActiveOutstandingLoanByBorrower(
        refMember,
      );
      if (!mounted) return;
      if (activeOutstanding != null) {
        final docno = activeOutstanding['docno']?.toString() ?? '-';
        final outstanding =
            (activeOutstanding['outstanding'] as num?)?.toDouble() ?? 0;
        _showSnack(
          TransactionUiText.loanHasOutstandingBlock(
            docno,
            outstanding.toStringAsFixed(2),
          ),
        );
        return;
      }
    }
    final success = _isEditMode
        ? await provider.updateLoan(
            localId: widget.initialData!['id']?.toString() ?? '',
            token: token,
            docno: widget.initialData!['docno']?.toString() ?? '',
            borrower: refMember,
            openingOutstanding: openingOutstanding,
            remark: _remarkCtrl.text.trim(),
            loandate: _loanDate,
            duedate: _dueDate,
            created: widget.initialData!['created']?.toString() ??
                DateTime.now().toIso8601String(),
            subLines: subLines,
          )
        : await provider.saveLoan(
            token: token,
            docno: _docnoCtrl.text.trim(),
            borrower: refMember,
            openingOutstanding: openingOutstanding,
            remark: _remarkCtrl.text.trim(),
            loandate: _loanDate,
            duedate: _dueDate,
            subLines: subLines,
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
          content: Text(msg, style: const TextStyle(fontFamily: _fontFamily)),
        ),
      );
  }

  Future<void> _syncBorrowerFieldWithMemberRegistry() async {
    if (_refMemberId.isEmpty) return;
    final ds = ServiceLocator.instance.get<MemberLocalDataSource>();
    final m = await ds.getMemberById(_refMemberId);
    if (!mounted) return;
    if (m != null) {
      setState(() {
        _borrowerCtrl.text = _formatMemberLabel(m);
      });
    } else {
      setState(() {
        _refMemberId = '';
      });
    }
  }

  void _openMemberRegisterPage() {
    if (!mounted) return;
    unawaited(
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => MemberProvider(prefix: []),
                child: const Member(),
              ),
            ),
          )
          .then((_) {}),
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
              TransactionUiText.loanQuickGuideHint,
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
      title: TransactionUiText.loanPageGuideTitle,
      items: [
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.loanRequiredBeforeSaveHint,
          accentColor: c.loanAmber,
          backgroundColor: c.iconBgLoan,
        ),
      ],
      children: [_buildQuickGuide(c)],
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

  Widget _buildOutstandingBorrowerHint(AppColors c) {
    if (_refMemberId.trim().isEmpty) return const SizedBox.shrink();
    final row = _outstandingLoanForBorrowerFromLoadedRows(_refMemberId.trim());
    if (row == null) return const SizedBox.shrink();
    final docno = row['docno']?.toString() ?? '-';
    final outstanding = (row['outstanding'] as num?)?.toDouble() ??
        double.tryParse(row['outstanding']?.toString() ?? '0') ??
        0;
    if (outstanding <= 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: c.expenseRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.expenseRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: c.expenseRed),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              TransactionUiText.loanHasOutstandingBlock(
                docno,
                outstanding.toStringAsFixed(2),
              ),
              style: _pageBodyStyle(c, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _outstandingLoanForBorrowerFromLoadedRows(
      String refMember) {
    final provider = Provider.of<LoanProvider?>(context, listen: false);
    final normalized = refMember.trim();
    if (provider == null || normalized.isEmpty) return null;
    for (final row in provider.rows) {
      final rowRef = (row['ref_member']?.toString() ?? '').trim();
      if (rowRef != normalized) continue;
      final outstanding = (row['outstanding'] as num?)?.toDouble() ??
          double.tryParse(row['outstanding']?.toString() ?? '0') ??
          0;
      if (outstanding > 0) return row;
    }
    return null;
  }

  bool _isFormReady() {
    final principal = _principalFromSubs;
    final opening =
        double.tryParse(_openingOutstandingCtrl.text.replaceAll(',', '')) ?? 0;
    final dueNotBeforeLoan = !_selectedDueDate.isBefore(
      DateTime(_selectedLoanDate.year, _selectedLoanDate.month,
          _selectedLoanDate.day),
    );
    return _refMemberId.trim().isNotEmpty &&
        (principal > 0 || opening > 0) &&
        !_subsMissingCategoryForPositiveAmount() &&
        dueNotBeforeLoan;
  }

  String _buildMissingRequiredText() {
    final missing = <String>[];
    if (_refMemberId.trim().isEmpty) {
      missing.add(TransactionUiText.loanBorrower);
    }
    final principal = _principalFromSubs;
    final opening =
        double.tryParse(_openingOutstandingCtrl.text.replaceAll(',', '')) ?? 0;
    if (principal <= 0 && opening <= 0) {
      missing.add(TransactionUiText.loanSubNeedPrincipalOrOpening);
    }
    if (_subsMissingCategoryForPositiveAmount()) {
      missing.add(TransactionUiText.loanSubNeedCategory);
    }
    if (_selectedDueDate.isBefore(
      DateTime(_selectedLoanDate.year, _selectedLoanDate.month,
          _selectedLoanDate.day),
    )) {
      missing.add(TransactionUiText.loanDueDate);
    }
    if (missing.isEmpty) return TransactionUiText.loanReadyToSave;
    return '${TransactionUiText.loanMissingRequiredPrefix}${missing.join(', ')}';
  }

  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
  }

  void _captureInitialSnapshot() {
    _initialDocNo = _docnoCtrl.text.trim();
    _initialBorrower = _borrowerCtrl.text.trim();
    _initialRefMemberId = _refMemberId.trim();
    _initialOpeningOutstanding = _openingOutstandingCtrl.text.trim();
    _initialRemark = _remarkCtrl.text.trim();
    _initialLoanDate = _loanDate.trim();
    _initialDueDate = _dueDate.trim();
    _initialSubsSnapshot = _serializeSubs();
  }

  bool _hasUnsavedChanges() {
    return _docnoCtrl.text.trim() != _initialDocNo ||
        _borrowerCtrl.text.trim() != _initialBorrower ||
        _refMemberId.trim() != _initialRefMemberId ||
        _openingOutstandingCtrl.text.trim() != _initialOpeningOutstanding ||
        _remarkCtrl.text.trim() != _initialRemark ||
        _loanDate.trim() != _initialLoanDate ||
        _dueDate.trim() != _initialDueDate ||
        _serializeSubs() != _initialSubsSnapshot;
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
    _refMemberId = '';
    _borrowerCtrl.clear();
    _openingOutstandingCtrl.clear();
    _remarkCtrl.clear();
    for (final r in _subRows) {
      r.dispose();
    }
    _subRows.clear();
    _bindDefaultSubRow();
    final now = DateTime.now();
    setState(() {
      _selectedLoanDate = now;
      _loanDate = now.toIso8601String();
      _selectedDueDate = now;
      _dueDate = now.toIso8601String();
    });
    await _refreshDocNoForSelectedDate();
    _captureInitialSnapshot();
    _showSnack(TransactionUiText.loanResetDone);
  }

  Future<void> _refreshDocNoForSelectedDate() async {
    final provider = Provider.of<LoanProvider?>(context, listen: false);
    final selectedDate = _selectedLoanDate.toIso8601String().split('T').first;
    final docNo = await provider?.fetchDocNo(
      tableName: 'loan',
      docDate: selectedDate,
    );
    if (!mounted || docNo == null || docNo.isEmpty) return;
    setState(() => _docnoCtrl.text = docNo);
  }
}

class _LoanSubRowEdit {
  _LoanSubRowEdit({
    this.refFundCategoryId = '',
    this.categoryLabel = '',
    String amountText = '',
    String remarkText = '',
  })  : categoryCtrl = TextEditingController(text: categoryLabel),
        amountCtrl = TextEditingController(text: amountText),
        remarkCtrl = TextEditingController(text: remarkText);

  String refFundCategoryId;
  String categoryLabel;
  final TextEditingController categoryCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController remarkCtrl;

  void dispose() {
    categoryCtrl.dispose();
    amountCtrl.dispose();
    remarkCtrl.dispose();
  }
}
