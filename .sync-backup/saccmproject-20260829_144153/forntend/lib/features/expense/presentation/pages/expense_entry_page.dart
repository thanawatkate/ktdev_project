// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/constants/money_type_pocket.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/expense_req_local_data_source.dart';
import 'package:saccm/features/approval/data/expense_entry_prefill_resolver.dart';
import 'package:saccm/features/expense/domain/models/expense_entry_prefill.dart';
import 'package:saccm/features/expense/domain/rules/expense_budget_source_rule.dart';
import 'package:saccm/features/expense/presentation/providers/expense_provider.dart';
import 'package:saccm/features/expense/presentation/widgets/expense_pay_cheque_lines_editor.dart';
import 'package:saccm/features/party/presentation/pages/party_management_page.dart';
import 'package:saccm/widgets/dialog/alertDialog/custom_autodismiss_alert.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// หน้าบันทึกรายจ่ายแบบฟอร์มเดียว — ตรวจยอดคงเหลือแหล่งเงินก่อนบันทึก
class ExpenseEntryPage extends StatelessWidget {
  const ExpenseEntryPage({super.key, this.prefill});

  final ExpenseEntryPrefill? prefill;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: _ExpenseEntryView(prefill: prefill),
    );
  }
}

class _ExpenseEntryView extends StatefulWidget {
  const _ExpenseEntryView({this.prefill});

  final ExpenseEntryPrefill? prefill;

  @override
  State<_ExpenseEntryView> createState() => _ExpenseEntryViewState();
}

class _ExpenseEntryViewState extends State<_ExpenseEntryView> {
  static const _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _budgetDs = BudgetSourceLocalDataSource();
  final _expenseReqDs =
      ServiceLocator.instance.get<ExpenseReqLocalDataSource>();
  final _expenseReqPrefillResolver = ExpenseEntryPrefillResolver();
  final _docnoCtrl = TextEditingController();
  final _payToCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _chequeLinesKey = GlobalKey<ExpensePayChequeLinesEditorState>();

  DateTime _selectedDocDate = DateTime.now();
  BudgetBalanceSnapshot? _budgetSnapshot;
  bool _amountExceedsAvailable = false;
  bool _lookupsLoading = true;
  String? _token;
  String? _userId;
  ExpenseEntryPrefill? _expenseReqPrefill;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountOrBudgetChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountOrBudgetChanged);
    _docnoCtrl.dispose();
    _payToCtrl.dispose();
    _detailCtrl.dispose();
    _remarkCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final p = context.read<ExpenseProvider>();
    await Future.wait([
      p.loadExpenseTypes(),
      p.loadBudgetSources(),
      p.loadMoneyTypes(),
      p.loadOffBudgetFundCategories(),
      p.loadChequeAccounts(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _token = prefs.getString('token');
      _userId = prefs.getString('userId');
    });
    await _refreshDocNo();
    final prefill = widget.prefill;
    if (prefill != null) {
      await _applyExpenseReqPrefill(prefill);
    }
    if (mounted) setState(() => _lookupsLoading = false);
  }

  Future<void> _applyExpenseReqPrefill(ExpenseEntryPrefill prefill) async {
    final p = context.read<ExpenseProvider>();
    p.applyEntryPrefill(prefill);
    _amountCtrl.text = prefill.amount;
    _detailCtrl.text = prefill.detail;
    _payToCtrl.text = prefill.payToName;
    final ref = prefill.referenceNote;
    _remarkCtrl.text = prefill.remark?.trim().isNotEmpty == true
        ? '${prefill.remark!.trim()}\n$ref'
        : ref;
    if (mounted) {
      setState(() => _expenseReqPrefill = prefill);
    } else {
      _expenseReqPrefill = prefill;
    }
    await _recomputeBudgetWarning();
  }

  Future<List<AppDropdownItem<String>>> _loadExpenseReqLookupItems() async {
    final rows = await _expenseReqDs.getApprovedReadyForExpenseEntry();
    return rows.map((item) {
      final amount =
          double.tryParse(item.amount.replaceAll(',', '').trim()) ?? 0;
      final amountText = NumberFormat('#,##0.00').format(amount);
      return AppDropdownItem<String>(
        value: item.id,
        label: '${item.docno} — ${item.memberLabel}',
        subtitle: '$amountText ${TransactionUiText.baht}',
      );
    }).toList();
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

  Future<void> _refreshDocNo() async {
    final p = context.read<ExpenseProvider>();
    final docDateStr = _selectedDocDate.toIso8601String().split('T').first;
    final no = await p.fetchDocNo(tableName: 'expense', docDate: docDateStr);
    if (!mounted) return;
    if (no != null) _docnoCtrl.text = no;
    setState(() {});
  }

  void _onAmountOrBudgetChanged() {
    unawaited(_recomputeBudgetWarning());
  }

  Future<void> _recomputeBudgetWarning() async {
    final p = context.read<ExpenseProvider>();
    final budgetId = p.budgetSourceCode.trim();
    final amt =
        double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    if (budgetId.isEmpty) {
      if (mounted) {
        setState(() {
          _budgetSnapshot = null;
          _amountExceedsAvailable = false;
        });
      }
      return;
    }
    final snap = await _budgetDs.getBudgetBalanceSnapshot(budgetId);
    if (!mounted) return;
    setState(() {
      _budgetSnapshot = snap;
      _amountExceedsAvailable =
          snap != null && amt > 0 && amt > snap.available + 0.000001;
    });
  }

  List<List<String>> _filteredBudgetRows(ExpenseProvider p) {
    if (p.expenseTypeCode.isEmpty) return const [];
    return ExpenseBudgetSourceRule.filterBudgetSources(
      allSources: p.budgetSource,
      expenseTypeId: p.expenseTypeCode,
      expenseTypeRows: p.expenseTypes,
    );
  }

  String? _selectedBudgetMasterCode(ExpenseProvider p) {
    if (p.budgetSourceCode.isEmpty) return null;
    for (final row in p.budgetSource) {
      if (row.length < 2 || row[0] != p.budgetSourceCode) continue;
      return ExpenseBudgetSourceRule.masterCodeFromBudgetRowLabel(row[1]);
    }
    return null;
  }

  bool _budgetSourceIsOffBudget(ExpenseProvider p) {
    if (p.budgetSourceCode.isEmpty) return false;
    for (final row in p.budgetSource) {
      if (row.length < 2 || row[0] != p.budgetSourceCode) continue;
      final mc = ExpenseBudgetSourceRule.masterCodeFromBudgetRowLabel(row[1]);
      if (mc == null) continue;
      return mc != 'GOV';
    }
    return false;
  }

  String? _moneyDomainForSave(ExpenseProvider p) {
    final mc = _selectedBudgetMasterCode(p);
    if (mc == 'GOV') return 'budget';
    if (mc != null) return 'off_budget';
    return null;
  }

  List<String> _selectedMoneyTypeRow(ExpenseProvider p) {
    if (p.moneyTypeCode.isEmpty) return const [];
    for (final row in p.moneyTypes) {
      if (row.isNotEmpty && row[0] == p.moneyTypeCode) return row;
    }
    return const [];
  }

  bool _isPayingByCheque(ExpenseProvider p) {
    final row = _selectedMoneyTypeRow(p);
    if (row.isEmpty) return false;
    final name = row.length > 1 ? row[1] : '';
    final code = row.length > 2 ? row[2] : '';
    return MoneyTypePocket.isCheque(code: code, name: name);
  }

  double _parseAmount() =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

  bool _isFormReady(ExpenseProvider p) {
    final offReady = !_budgetSourceIsOffBudget(p) ||
        (p.fundCategoryId.isNotEmpty && p.offBudgetFundCategories.isNotEmpty);
    final chequeReady = !_isPayingByCheque(p) ||
        _chequeLinesKey.currentState?.validate() == null;
    final amt = _parseAmount();
    return !_lookupsLoading &&
        p.expenseTypeCode.isNotEmpty &&
        p.budgetSourceCode.isNotEmpty &&
        p.moneyTypeCode.isNotEmpty &&
        offReady &&
        chequeReady &&
        _payToCtrl.text.trim().isNotEmpty &&
        _detailCtrl.text.trim().isNotEmpty &&
        amt > 0 &&
        !_amountExceedsAvailable;
  }

  Future<List<AppDropdownItem<String>>> _loadPayeeLookupItems() async {
    final p = context.read<ExpenseProvider>();
    final rows = await p.loadReceiverPartyRowsLocalForPicker();
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

  void _openPartyManagementPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PartyManagementPage(),
      ),
    );
  }

  Future<void> _onSave() async {
    final p = context.read<ExpenseProvider>();
    if (!_isFormReady(p)) return;

    final amountStr = _amountCtrl.text.replaceAll(',', '').trim();
    final subData = <Map<String, dynamic>>[
      {
        'amount': amountStr,
        'remark': _remarkCtrl.text.trim(),
        'refexpensetype': p.expenseTypeCode,
        'refmoneytype': p.moneyTypeCode,
        if (_budgetSourceIsOffBudget(p) && p.fundCategoryId.isNotEmpty)
          'refincometype': p.fundCategoryId,
      },
    ];

    final isCheque = _isPayingByCheque(p);
    final payCheque = isCheque
        ? (_chequeLinesKey.currentState
                ?.buildPayload(remark: _remarkCtrl.text) ??
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

    if (isCheque) {
      final err = _chequeLinesKey.currentState?.validate();
      if (err != null) {
        showAutoDismissAlert(
          context,
          TransactionUiText.warning,
          err,
          3,
        );
        return;
      }
    }

    final ok = await p.saveExpense(
      token: _token ?? '',
      docno: _docnoCtrl.text.trim(),
      docdate: _selectedDocDate.toIso8601String(),
      amount: amountStr,
      detail: _detailCtrl.text.trim(),
      remark: _remarkCtrl.text.trim(),
      partyName: _payToCtrl.text.trim(),
      refMember: _userId ?? '',
      subData: subData,
      payCheque: payCheque,
      bankAmount: bankAmount,
      moneyDomain: _moneyDomainForSave(p),
      refExpenseReq: _expenseReqPrefill?.expenseReqId,
      refExpenseReqServerId: _expenseReqPrefill?.expenseReqServerId,
    );

    if (!mounted) return;
    if (ok) {
      final prefill = _expenseReqPrefill;
      if (prefill != null) {
        await ServiceLocator.instance
            .get<ExpenseReqLocalDataSource>()
            .markExpenseRecorded(prefill.expenseReqId);
      }
      showAutoDismissAlert(
        context,
        TransactionUiText.saveSuccessTitle,
        TransactionUiText.saveSuccessWithLocalServerNote(
          TransactionUiText.saveExpenseSuccess,
          serverReachable: false,
        ),
        5,
      );
      Navigator.of(context).pop(true);
    } else {
      showAutoDismissAlert(
        context,
        TransactionUiText.saveFailedTitle,
        p.error ?? TransactionUiText.tryAgain,
        null,
      );
    }
  }

  PreferredSizeWidget _buildAppBar(AppColors c, ExpenseProvider p) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: c.cardWhite,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: c.textPrimary),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        TransactionUiText.expenseEntryFormTitle,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.help_outline_rounded,
            size: 20,
            color: c.textSecondary,
          ),
          tooltip: TransactionUiText.expensePageGuideTitle,
          onPressed: _showPageGuideDialog,
        ),
        AppBarActionButton(
          label: TransactionUiText.save,
          onPressed: _isFormReady(p) ? _onSave : null,
          isLoading: p.isLoading,
          isEnabled: _isFormReady(p),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: c.cardBorder),
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
        PageGuideItem(
          icon: Icons.tips_and_updates_outlined,
          text: TransactionUiText.expenseQuickGuideHint,
          backgroundColor: c.iconBgExpense,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(AppColors c,
      {required IconData icon, required String title}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.sp16, AppTheme.sp12, AppTheme.sp16, AppTheme.sp8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.expenseRed),
          const SizedBox(width: AppTheme.sp8),
          Text(
            title,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Consumer<ExpenseProvider>(
      builder: (context, p, _) {
        final budgetRows = _filteredBudgetRows(p);
        return PopScope(
          canPop: true,
          child: Scaffold(
            backgroundColor: c.background,
            appBar: _buildAppBar(c, p),
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _lookupsLoading
                  ? Center(
                      child: CircularProgressIndicator(color: c.expenseRed))
                  : SingleChildScrollView(
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
                                icon: Icons.payments_outlined,
                                iconColor: c.expenseRed,
                                iconBgColor: c.iconBgExpense,
                                title: TransactionUiText.expenseEntryFormTitle,
                                subtitle: TransactionUiText.reviewBeforeSave,
                                quickHint: TransactionUiText
                                    .expenseRequiredBeforeSaveHint,
                                hintAccentColor: c.expenseRed,
                                hintBorderColor: c.cardBorder,
                                textPrimaryColor: c.textPrimary,
                                showQuickHint: false,
                              ),
                              if (_expenseReqPrefill != null) ...[
                                const SizedBox(height: AppTheme.sp12),
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.sp12),
                                  decoration: BoxDecoration(
                                    color: c.iconBgIncome,
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.r12),
                                    border: Border.all(
                                      color:
                                          c.incomeGreen.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: c.incomeGreen,
                                        size: 22,
                                      ),
                                      const SizedBox(width: AppTheme.sp8),
                                      Expanded(
                                        child: Text(
                                          '${_expenseReqPrefill!.referenceNote}\n${TransactionUiText.expenseEntryPrefillHint}',
                                          style: TextStyle(
                                            fontFamily: _fontFamily,
                                            fontSize: 13,
                                            height: 1.4,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppTheme.sp16),
                              Container(
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          AppDateInput(
                                            label: TransactionUiText.date,
                                            initialValue: _selectedDocDate,
                                            prefixIcon: const Icon(
                                                Icons.calendar_today_outlined),
                                            onChanged: (d) async {
                                              if (d == null) return;
                                              setState(
                                                  () => _selectedDocDate = d);
                                              await _refreshDocNo();
                                            },
                                          ),
                                          const SizedBox(height: AppTheme.sp12),
                                          AppInput(
                                            label: TransactionUiText.docNumber,
                                            hint:
                                                TransactionUiText.autoGenerated,
                                            helperText: TransactionUiText
                                                .docNoAutoHelper,
                                            readOnly: true,
                                            controller: _docnoCtrl,
                                            prefixIcon:
                                                const Icon(Icons.tag_rounded),
                                          ),
                                          const SizedBox(height: AppTheme.sp12),
                                          AppLookupPickerField<String>(
                                            label: TransactionUiText
                                                .expenseReqReferenceLabel,
                                            hint: TransactionUiText
                                                .expenseReqReferencePickerHint,
                                            helperText: TransactionUiText
                                                .expenseReqReferenceHelper,
                                            value: _expenseReqPrefill
                                                ?.expenseReqId,
                                            displayLabel: _expenseReqPrefill
                                                ?.referenceNote,
                                            clearable: false,
                                            pickerTitle: TransactionUiText
                                                .expenseReqReferencePickerTitle,
                                            searchHint: TransactionUiText
                                                .expenseReqReferenceSearchHint,
                                            loadingText: TransactionUiText
                                                .expenseReqReferenceLoading,
                                            emptyText: TransactionUiText
                                                .expenseReqReferenceEmpty,
                                            loadItems:
                                                _loadExpenseReqLookupItems,
                                            onChanged: _selectExpenseReq,
                                            prefixIcon: const Icon(Icons
                                                .assignment_turned_in_outlined),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(height: 1, color: c.cardBorder),
                                    _buildSectionHeader(
                                      c,
                                      icon: Icons.category_outlined,
                                      title: TransactionUiText
                                          .expenseAccountingStep1Label,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppTheme.sp16,
                                        0,
                                        AppTheme.sp16,
                                        AppTheme.sp16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          AppLookupPickerField<String>(
                                            label: TransactionUiText
                                                .expenseTypeTitle,
                                            hint: TransactionUiText
                                                .expenseChooseTypeFirstHint,
                                            required: true,
                                            prefixIcon: const Icon(
                                                Icons.account_tree_outlined),
                                            helperText: TransactionUiText
                                                .expenseTypeHelperText,
                                            value: p.expenseTypeCode.isEmpty
                                                ? null
                                                : p.expenseTypeCode,
                                            clearable: false,
                                            items: p.expenseTypes
                                                .where((e) =>
                                                    e.isNotEmpty &&
                                                    e[0].isNotEmpty)
                                                .map(
                                                  (e) =>
                                                      AppDropdownItem<String>(
                                                    value: e[0],
                                                    label: e.length > 1
                                                        ? e[1]
                                                        : e[0],
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) {
                                              p.addExpenseTypeCode(v ?? '');
                                              p.addBudgetSourceCode('');
                                              setState(() {});
                                              unawaited(
                                                  _recomputeBudgetWarning());
                                            },
                                          ),
                                          const SizedBox(height: AppTheme.sp12),
                                          AppLookupPickerField<String>(
                                            label: TransactionUiText
                                                .budgetSourceTitle,
                                            hint: TransactionUiText
                                                .expenseChooseTypeFirstHint,
                                            required: true,
                                            enabled:
                                                p.expenseTypeCode.isNotEmpty,
                                            prefixIcon: const Icon(
                                                Icons.savings_outlined),
                                            helperText: budgetRows.isEmpty
                                                ? TransactionUiText
                                                    .expenseNoBudgetSourceForTypeHelper
                                                : TransactionUiText
                                                    .expenseBudgetSourceHelper,
                                            value: p.budgetSourceCode.isEmpty
                                                ? null
                                                : p.budgetSourceCode,
                                            items: budgetRows
                                                .where((e) =>
                                                    e.isNotEmpty &&
                                                    e[0].isNotEmpty)
                                                .map(
                                                  (e) =>
                                                      AppDropdownItem<String>(
                                                    value: e[0],
                                                    label: e.length > 1
                                                        ? e[1]
                                                        : e[0],
                                                  ),
                                                )
                                                .toList(),
                                            clearable: false,
                                            onChanged: (v) {
                                              p.addBudgetSourceCode(v ?? '');
                                              if (!_budgetSourceIsOffBudget(
                                                  p)) {
                                                p.addFundCategoryId('');
                                              }
                                              setState(() {});
                                              unawaited(
                                                  _recomputeBudgetWarning());
                                            },
                                          ),
                                          if (_budgetSourceIsOffBudget(p)) ...[
                                            const SizedBox(
                                                height: AppTheme.sp12),
                                            AppLookupPickerField<String>(
                                              label: TransactionUiText
                                                  .expenseFundCategoryTitle,
                                              hint: TransactionUiText
                                                  .expenseSelectFundCategory,
                                              required: true,
                                              prefixIcon: const Icon(
                                                  Icons.list_alt_rounded),
                                              helperText: TransactionUiText
                                                  .expenseFundCategoryHelper,
                                              value: p.fundCategoryId.isEmpty
                                                  ? null
                                                  : p.fundCategoryId,
                                              items: p.offBudgetFundCategories
                                                  .where((e) =>
                                                      e.isNotEmpty &&
                                                      e[0].isNotEmpty)
                                                  .map(
                                                    (e) =>
                                                        AppDropdownItem<String>(
                                                      value: e[0],
                                                      label: e.length > 1
                                                          ? e[1]
                                                          : e[0],
                                                    ),
                                                  )
                                                  .toList(),
                                              clearable: false,
                                              onChanged: (v) {
                                                p.addFundCategoryId(v ?? '');
                                                setState(() {});
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Divider(height: 1, color: c.cardBorder),
                                    _buildSectionHeader(
                                      c,
                                      icon: Icons.payments_rounded,
                                      title: TransactionUiText
                                          .expenseAccountingStep3Label,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppTheme.sp16,
                                        0,
                                        AppTheme.sp16,
                                        AppTheme.sp16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          AppLookupPickerField<String>(
                                            label: TransactionUiText
                                                .expenseMoneyChannelTitle,
                                            hint: TransactionUiText
                                                .expenseSelectMoneyChannel,
                                            required: true,
                                            prefixIcon: const Icon(Icons
                                                .account_balance_wallet_outlined),
                                            helperText: TransactionUiText
                                                .expenseMoneyChannelHelper,
                                            value: p.moneyTypeCode.isEmpty
                                                ? null
                                                : p.moneyTypeCode,
                                            items: p.moneyTypes
                                                .where((e) =>
                                                    e.isNotEmpty &&
                                                    e[0].isNotEmpty)
                                                .map(
                                                  (e) =>
                                                      AppDropdownItem<String>(
                                                    value: e[0],
                                                    label: e.length > 1
                                                        ? e[1]
                                                        : e[0],
                                                  ),
                                                )
                                                .toList(),
                                            clearable: false,
                                            onChanged: (v) {
                                              p.addMoneyTypeCode(v ?? '');
                                              if (!_isPayingByCheque(p)) {
                                                p.addChequeAccountId('');
                                              }
                                              setState(() {});
                                            },
                                          ),
                                          const SizedBox(height: AppTheme.sp12),
                                          AppInput(
                                            label:
                                                TransactionUiText.totalAmount,
                                            hint: '0.00',
                                            required: true,
                                            helperText: TransactionUiText
                                                .positiveAmountHelper,
                                            controller: _amountCtrl,
                                            action: const AppInputAction.number(
                                                allowDecimal: true),
                                            textAlign: TextAlign.right,
                                            prefixIcon: const Icon(
                                                Icons.attach_money_rounded),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                          if (_isPayingByCheque(p)) ...[
                                            const SizedBox(
                                                height: AppTheme.sp12),
                                            Text(
                                              TransactionUiText
                                                  .expenseChequeStepLabel,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: c.textPrimary,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ExpensePayChequeLinesEditor(
                                              key: _chequeLinesKey,
                                              provider: p,
                                              expenseTotal: _parseAmount(),
                                              onChanged: () {
                                                if (mounted) setState(() {});
                                              },
                                            ),
                                          ],
                                          if (_budgetSnapshot != null &&
                                              p.budgetSourceCode
                                                  .isNotEmpty) ...[
                                            const SizedBox(
                                                height: AppTheme.sp8),
                                            Text(
                                              '${TransactionUiText.expenseBudgetAvailableLabel}: ${NumberFormat('#,##0.00').format(_budgetSnapshot!.available)} ${TransactionUiText.baht}',
                                              style: TextStyle(
                                                fontFamily: _fontFamily,
                                                fontSize: 12,
                                                color: c.textSecondary,
                                              ),
                                            ),
                                          ],
                                          if (_amountExceedsAvailable) ...[
                                            const SizedBox(
                                                height: AppTheme.sp8),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                    Icons.warning_amber_rounded,
                                                    color: c.expenseRed,
                                                    size: 20),
                                                const SizedBox(
                                                    width: AppTheme.sp8),
                                                Expanded(
                                                  child: Text(
                                                    TransactionUiText
                                                        .expenseAmountExceedsAvailableWarning,
                                                    style: TextStyle(
                                                      fontFamily: _fontFamily,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: c.expenseRed,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Divider(height: 1, color: c.cardBorder),
                                    _buildSectionHeader(
                                      c,
                                      icon: Icons.notes_rounded,
                                      title:
                                          TransactionUiText.additionalDetails,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppTheme.sp16,
                                        0,
                                        AppTheme.sp16,
                                        AppTheme.sp16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          AppLookupPickerField<String>(
                                            label: TransactionUiText.payTo,
                                            hint: TransactionUiText
                                                .expensePayeePickerTitle,
                                            required: true,
                                            value:
                                                _payToCtrl.text.trim().isEmpty
                                                    ? null
                                                    : _payToCtrl.text.trim(),
                                            displayLabel:
                                                _payToCtrl.text.trim().isEmpty
                                                    ? null
                                                    : _payToCtrl.text.trim(),
                                            clearable: false,
                                            pickerTitle: TransactionUiText
                                                .expensePayeePickerTitle,
                                            searchHint: TransactionUiText
                                                .expensePayeePickerSearchHint,
                                            loadingText: TransactionUiText
                                                .expensePayeePickerLoading,
                                            emptyText: TransactionUiText
                                                .payToNoReceiverDialogBody,
                                            emptyActionLabel: TransactionUiText
                                                .receiveFromGoAddParty,
                                            onEmptyAction:
                                                _openPartyManagementPage,
                                            loadItems: _loadPayeeLookupItems,
                                            onChanged: (v) {
                                              final selected = v?.trim() ?? '';
                                              if (selected.isEmpty) return;
                                              setState(() =>
                                                  _payToCtrl.text = selected);
                                            },
                                            prefixIcon: const Icon(
                                                Icons.person_outline_rounded),
                                          ),
                                          const SizedBox(height: AppTheme.sp12),
                                          AppInput(
                                            label: TransactionUiText.detail,
                                            hint: TransactionUiText
                                                .expenseDetailHint,
                                            required: true,
                                            helperText: TransactionUiText
                                                .expenseDetailRequiredHelper,
                                            controller: _detailCtrl,
                                            prefixIcon: const Icon(
                                                Icons.subject_rounded),
                                            minLines: 2,
                                            maxLines: 4,
                                            onChanged: (_) => setState(() {}),
                                          ),
                                          const SizedBox(height: AppTheme.sp12),
                                          AppInput(
                                            label: TransactionUiText.remark,
                                            hint: TransactionUiText.remarkHint,
                                            controller: _remarkCtrl,
                                            prefixIcon: const Icon(
                                                Icons.edit_note_rounded),
                                            minLines: 1,
                                            maxLines: 3,
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.sp16),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
