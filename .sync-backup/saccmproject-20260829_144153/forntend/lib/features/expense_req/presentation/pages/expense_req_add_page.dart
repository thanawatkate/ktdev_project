// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/local_data_source/member_local_data_source.dart';
import 'package:saccm/core/services/app_notification_service.dart';
import 'package:saccm/features/expense_req/presentation/providers/expense_req_provider.dart';
import 'package:saccm/features/member/presentation/pages/member_page.dart'
    show Member;
import 'package:saccm/features/member/presentation/providers/member_provider.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseReqAddPage extends StatelessWidget {
  const ExpenseReqAddPage({super.key, this.embeddedInHome = false});

  final bool embeddedInHome;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseReqProvider()..loadLookups(),
      child: _ExpenseReqAddView(embeddedInHome: embeddedInHome),
    );
  }
}

class _ExpenseReqAddView extends StatefulWidget {
  const _ExpenseReqAddView({required this.embeddedInHome});

  final bool embeddedInHome;

  @override
  State<_ExpenseReqAddView> createState() => _ExpenseReqAddViewState();
}

class _ResponsiveFormField {
  const _ResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

class _ExpenseReqAddViewState extends State<_ExpenseReqAddView> {
  static const _font = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;
  final _docnoCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _budgetDs = BudgetSourceLocalDataSource();
  String _refMemberId = '';
  String? _token;
  bool _bootstrapping = true;
  Timer? _autoSaveDebounce;
  String? _autoDraftLocalId;
  String? _lastAutoDraftSignature;
  bool _isAutoSaving = false;
  String _autoDraftMessage = TransactionUiText.autoDraftWaiting;
  BudgetBalanceSnapshot? _budgetSnapshot;
  bool _amountExceedsAvailable = false;
  String _lastBudgetCheckSignature = '';

  @override
  void initState() {
    super.initState();
    _docnoCtrl.addListener(_onAnyFieldChanged);
    _memberCtrl.addListener(_onAnyFieldChanged);
    _detailCtrl.addListener(_onAnyFieldChanged);
    _amountCtrl.addListener(_onAnyFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _docnoCtrl.removeListener(_onAnyFieldChanged);
    _memberCtrl.removeListener(_onAnyFieldChanged);
    _detailCtrl.removeListener(_onAnyFieldChanged);
    _amountCtrl.removeListener(_onAnyFieldChanged);
    _docnoCtrl.dispose();
    _memberCtrl.dispose();
    _detailCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final docno = await context.read<ExpenseReqProvider>().fetchDocNo();
    if (mounted && docno != null) _docnoCtrl.text = docno;
    if (mounted) setState(() => _bootstrapping = false);
  }

  Future<List<AppDropdownItem<String>>> _loadMemberLookupItems() async {
    final ds = ServiceLocator.instance.get<MemberLocalDataSource>();
    final rows = await ds.getAllMembers();
    return rows.map((m) {
      final code = m.code.trim();
      final name = m.name.trim();
      final label = code.isNotEmpty && name.isNotEmpty
          ? '$code — $name'
          : (name.isNotEmpty ? name : code);
      return AppDropdownItem<String>(
        value: m.id,
        label: label,
      );
    }).toList();
  }

  void _openMemberPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => MemberProvider(prefix: []),
          child: const Member(),
        ),
      ),
    );
  }

  Future<String?> _saveAndSubmit() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.noPermissionData,
      );
      return null;
    }
    if (_refMemberId.isEmpty) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.expenseReqMemberRequired,
      );
      return null;
    }
    if (context.read<ExpenseReqProvider>().budgetSourceId.isEmpty) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.selectBudgetSource,
      );
      return null;
    }
    if (context.read<ExpenseReqProvider>().fundCategoryId.isEmpty) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.expenseReqFundCategoryRequired,
      );
      return null;
    }
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.expenseReqAmountRequired,
      );
      return null;
    }
    await _recomputeBudgetWarning();
    if (_amountExceedsAvailable) {
      AppNotificationService.instance.showWarning(
        TransactionUiText.warning,
        TransactionUiText.expenseAmountExceedsAvailableWarning,
      );
      return null;
    }
    final p = context.read<ExpenseReqProvider>();
    final localId = await p.upsertAutoDraft(
      localId: _autoDraftLocalId,
      token: token,
      docno: _docnoCtrl.text.trim(),
      refMember: _refMemberId,
      memberName: _memberCtrl.text.trim(),
      amount: amount.toStringAsFixed(2),
      detail: _detailCtrl.text.trim(),
    );
    if (localId == null) {
      if (p.error != null && mounted) {
        AppNotificationService.instance
            .showError(TransactionUiText.error, p.error!);
      }
      return null;
    }
    _autoDraftLocalId = localId;
    _lastAutoDraftSignature = _buildAutoDraftSignature();
    final ok = await p.submitForApproval(localId: localId, token: token);
    if (!ok && mounted && p.error != null) {
      AppNotificationService.instance
          .showError(TransactionUiText.error, p.error!);
      return null;
    }
    if (mounted) {
      AppNotificationService.instance.showSuccess(
        TransactionUiText.success,
        TransactionUiText.expenseReqSubmitSuccess,
      );
    }
    return localId;
  }

  bool _canAutoSaveDraft() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    return !_bootstrapping &&
        (_token?.isNotEmpty ?? false) &&
        _docnoCtrl.text.trim().isNotEmpty &&
        _refMemberId.isNotEmpty &&
        context.read<ExpenseReqProvider>().budgetSourceId.isNotEmpty &&
        context.read<ExpenseReqProvider>().fundCategoryId.isNotEmpty &&
        amount > 0;
  }

  String _buildAutoDraftSignature() {
    final p = context.read<ExpenseReqProvider>();
    final amount = (double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0)
        .toStringAsFixed(2);
    return [
      _docnoCtrl.text.trim(),
      _refMemberId,
      _memberCtrl.text.trim(),
      p.budgetSourceId,
      p.fundCategoryId,
      amount,
      _detailCtrl.text.trim(),
    ].join('|');
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    if (!_canAutoSaveDraft()) {
      if (mounted && _autoDraftMessage != TransactionUiText.autoDraftWaiting) {
        setState(() => _autoDraftMessage = TransactionUiText.autoDraftWaiting);
      }
      return;
    }
    _autoSaveDebounce = Timer(
      const Duration(milliseconds: 1600),
      _runAutoSaveDraft,
    );
  }

  void _scheduleBudgetCheck() {
    final p = context.read<ExpenseReqProvider>();
    final signature = '${p.budgetSourceId}|${_amountCtrl.text.trim()}';
    if (signature == _lastBudgetCheckSignature) return;
    _lastBudgetCheckSignature = signature;
    unawaited(_recomputeBudgetWarning());
  }

  Future<void> _recomputeBudgetWarning() async {
    final p = context.read<ExpenseReqProvider>();
    final budgetId = p.budgetSourceId.trim();
    if (budgetId.isEmpty) {
      if (mounted) {
        setState(() {
          _budgetSnapshot = null;
          _amountExceedsAvailable = false;
        });
      }
      return;
    }

    final requestedBudgetId = budgetId;
    final snap = await _budgetDs.getBudgetBalanceSnapshot(requestedBudgetId);
    if (!mounted) return;

    final latestBudgetId = context.read<ExpenseReqProvider>().budgetSourceId;
    if (latestBudgetId != requestedBudgetId) return;
    final latestAmount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    setState(() {
      _budgetSnapshot = snap;
      _amountExceedsAvailable = snap != null &&
          latestAmount > 0 &&
          latestAmount > snap.available + 0.000001;
    });
  }

  Future<void> _runAutoSaveDraft() async {
    if (!_canAutoSaveDraft()) return;
    final signature = _buildAutoDraftSignature();
    if (signature == _lastAutoDraftSignature) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    setState(() {
      _isAutoSaving = true;
      _autoDraftMessage = TransactionUiText.autoDraftSaving;
    });
    final p = context.read<ExpenseReqProvider>();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final localId = await p.upsertAutoDraft(
      localId: _autoDraftLocalId,
      token: token,
      docno: _docnoCtrl.text.trim(),
      refMember: _refMemberId,
      memberName: _memberCtrl.text.trim(),
      amount: amount.toStringAsFixed(2),
      detail: _detailCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = context.watch<ExpenseReqProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isReadyToSave = _isFormReady(p);
    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          title: widget.embeddedInHome
              ? const SizedBox.shrink()
              : const Text(
                  TransactionUiText.expenseReqAddTitle,
                  style:
                      TextStyle(fontFamily: _font, fontWeight: FontWeight.w600),
                ),
          backgroundColor: c.cardWhite,
          elevation: 0,
          actions: [
            Padding(
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
                    tooltip: TransactionUiText.expenseReqPageGuideTitle,
                    onPressed: _showPageGuideDialog,
                  ),
                  AppBarActionButton(
                    label: TransactionUiText.expenseReqSaveAndSubmit,
                    onPressed:
                        isReadyToSave && !p.isLoading ? _submitOnPressed : null,
                    isLoading: p.isLoading,
                    isEnabled: isReadyToSave && !p.isLoading,
                    isPrimary: true,
                  ),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.cardBorder),
          ),
        ),
        body: _bootstrapping
            ? Center(child: CircularProgressIndicator(color: c.expenseRed))
            : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                            icon: Icons.assignment_outlined,
                            iconColor: scheme.primary,
                            iconBgColor: c.iconBgExpense,
                            title: TransactionUiText.expenseReqAddTitle,
                            subtitle: TransactionUiText.reviewBeforeSave,
                            quickHint: TransactionUiText
                                .expenseReqRequiredBeforeSaveHint,
                            hintAccentColor: scheme.primary,
                            hintBorderColor: c.cardBorder,
                            textPrimaryColor: c.textPrimary,
                            showQuickHint: false,
                          ),
                          const SizedBox(height: AppTheme.sp16),
                          _buildFormCard(c, p),
                          const SizedBox(height: AppTheme.sp16),
                          _buildActionRow(c, p),
                          const SizedBox(height: AppTheme.sp24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _showPageGuideDialog() async {
    final c = AppColors.of(context);
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.expenseReqPageGuideTitle,
      items: [
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.expenseReqRequiredBeforeSaveHint,
          backgroundColor: c.iconBgExpense,
        ),
        PageGuideItem(
          icon: Icons.tips_and_updates_outlined,
          text: TransactionUiText.expenseReqQuickGuideHint,
          backgroundColor: c.iconBgExpense,
        ),
      ],
    );
  }

  Widget _buildFormCard(AppColors c, ExpenseReqProvider p) {
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
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.docNumber,
                        helperText: TransactionUiText.docNoAutoHelper,
                        controller: _docnoCtrl,
                        readOnly: true,
                        prefixIcon: const Icon(Icons.tag_rounded),
                      ),
                    ),
                    _ResponsiveFormField(
                      span: columnCount >= 4 ? 2 : 1,
                      child: _buildRequesterField(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.cardBorder),
              _buildSectionHeader(
                c,
                icon: Icons.account_balance_wallet_outlined,
                title: TransactionUiText.amountTypeSection,
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
                      span: columnCount >= 4 ? 2 : 1,
                      child: AppLookupPickerField<String>(
                        label: TransactionUiText.budgetSourceTitle,
                        required: true,
                        helperText: TransactionUiText.expenseBudgetSourceHelper,
                        value:
                            p.budgetSourceId.isEmpty ? null : p.budgetSourceId,
                        clearable: false,
                        items: p.budgetSources
                            .map(
                              (r) => AppDropdownItem<String>(
                                value: r[0],
                                label: r[1],
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          p.setBudgetSourceId(v);
                          _scheduleAutoSave();
                          _scheduleBudgetCheck();
                          setState(() {});
                        },
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppLookupPickerField<String>(
                        label: TransactionUiText.expenseReqFundCategoryLabel,
                        required: true,
                        value:
                            p.fundCategoryId.isEmpty ? null : p.fundCategoryId,
                        clearable: false,
                        items: p.fundCategories
                            .map(
                              (r) => AppDropdownItem<String>(
                                value: r[0],
                                label: r[1],
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          p.setFundCategoryId(v);
                          _scheduleAutoSave();
                          setState(() {});
                        },
                      ),
                    ),
                    _ResponsiveFormField(
                      child: AppInput(
                        label: TransactionUiText.incomeMissingFieldAmount,
                        helperText: TransactionUiText.positiveAmountHelper,
                        required: true,
                        controller: _amountCtrl,
                        action: const AppInputAction.number(allowDecimal: true),
                        textAlign: TextAlign.right,
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              if (_budgetSnapshot != null && p.budgetSourceId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.sp16,
                    0,
                    AppTheme.sp16,
                    AppTheme.sp16,
                  ),
                  child: _buildBudgetBalanceHint(c),
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
                      child: AppInput(
                        label: TransactionUiText.description,
                        controller: _detailCtrl,
                        minLines: 2,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        prefixIcon: const Icon(Icons.short_text_rounded),
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

  Widget _buildRequesterField() {
    return ListenableBuilder(
      listenable: _memberCtrl,
      builder: (context, _) {
        final requester = _memberCtrl.text.trim();
        return AppLookupPickerField<String>(
          label: TransactionUiText.expenseReqRequesterLabel,
          required: true,
          value: _refMemberId.isEmpty ? null : _refMemberId,
          displayLabel: requester.isEmpty ? null : requester,
          clearable: false,
          pickerTitle: TransactionUiText.loanBorrowerPickerTitle,
          searchHint: TransactionUiText.loanBorrowerPickerSearchHint,
          loadingText: TransactionUiText.loanBorrowerPickerLoading,
          emptyText: TransactionUiText.loanBorrowerNoMembersBody,
          emptyActionLabel: TransactionUiText.loanBorrowerGoRegister,
          onEmptyAction: _openMemberPage,
          loadItems: _loadMemberLookupItems,
          onChanged: (v) async {
            final memberId = v?.trim() ?? '';
            if (memberId.isEmpty) return;
            final options = await _loadMemberLookupItems();
            final selected =
                options.cast<AppDropdownItem<String>?>().firstWhere(
                      (item) => item?.value == memberId,
                      orElse: () => null,
                    );
            if (!mounted || selected == null) return;
            setState(() => _refMemberId = memberId);
            _memberCtrl.text = selected.label;
          },
          prefixIcon: const Icon(Icons.person_outline_rounded),
        );
      },
    );
  }

  Widget _buildActionRow(AppColors c, ExpenseReqProvider p) {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final isReadyToSave = _isFormReady(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          saveLabel: TransactionUiText.expenseReqSaveAndSubmit,
          isSaving: p.isLoading,
          onSave: _submitOnPressed,
          isSaveEnabled: isReadyToSave && !p.isLoading,
          saveDisabledHint: isReadyToSave ? null : _buildMissingRequiredText(p),
          isEditMode: false,
          cancelLabel: TransactionUiText.cancel,
          showSaveButton: false,
        ),
        const SizedBox(height: AppTheme.sp8),
        _buildAutoDraftStatus(c),
      ],
    );
  }

  Future<void> _submitOnPressed() async {
    final localId = await _saveAndSubmit();
    if (localId == null || !mounted) return;
    Navigator.pop(context, true);
  }

  Widget _buildAutoDraftStatus(AppColors c) {
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
              fontFamily: _font,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveReadinessHint(
    AppColors c,
    ExpenseReqProvider p,
    bool isReadyToSave,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp8,
      ),
      decoration: BoxDecoration(
        color: isReadyToSave ? c.iconBgExpense : c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(
          color: isReadyToSave
              ? c.expenseRed.withValues(alpha: 0.55)
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
              style: TextStyle(
                fontFamily: _font,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: isReadyToSave ? c.expenseRed : c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isFormReady(ExpenseReqProvider p) {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    return _docnoCtrl.text.trim().isNotEmpty &&
        _refMemberId.isNotEmpty &&
        p.budgetSourceId.isNotEmpty &&
        p.fundCategoryId.isNotEmpty &&
        amount > 0 &&
        !_amountExceedsAvailable;
  }

  String _buildMissingRequiredText(ExpenseReqProvider p) {
    final missing = <String>[];
    if (_refMemberId.isEmpty) {
      missing.add(TransactionUiText.expenseReqRequesterLabel);
    }
    if (p.budgetSourceId.isEmpty) {
      missing.add(TransactionUiText.budgetSourceTitle);
    }
    if (p.fundCategoryId.isEmpty) {
      missing.add(TransactionUiText.expenseReqFundCategoryLabel);
    }
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      missing.add(TransactionUiText.incomeMissingFieldAmount);
    }
    if (_amountExceedsAvailable) {
      missing.add(TransactionUiText.expenseAmountExceedsAvailableWarning);
    }
    if (missing.isEmpty) return TransactionUiText.expenseReadyToSave;
    return '${TransactionUiText.expenseMissingRequiredPrefix}${missing.join(', ')}';
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

  void _onAnyFieldChanged() {
    if (!mounted) return;
    _scheduleAutoSave();
    _scheduleBudgetCheck();
    setState(() {});
  }

  Widget _buildBudgetBalanceHint(AppColors c) {
    final snap = _budgetSnapshot;
    if (snap == null) return const SizedBox.shrink();
    final color = _amountExceedsAvailable
        ? Theme.of(context).colorScheme.error
        : c.textSecondary;
    return Row(
      children: [
        Icon(
          _amountExceedsAvailable
              ? Icons.warning_amber_rounded
              : Icons.account_balance_wallet_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: AppTheme.sp8),
        Expanded(
          child: Text(
            '${TransactionUiText.expenseBudgetAvailableLabel}: '
            '${NumberFormat('#,##0.00').format(snap.available)} '
            '${TransactionUiText.baht}',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
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
          Text(
            title,
            style: TextStyle(
              fontFamily: _font,
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
}
