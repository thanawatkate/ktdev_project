import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/local_data_source/budget_source_local_data_source.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/budget_source/data/models/budget_source_model.dart';
import 'package:saccm/features/income/presentation/providers/income_provider.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/register/data/repositories/deposit_register_repository_offline.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// รับเงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย — บันทึกทะเบียน + ใบรับเงิน (TEAM_RULES §4.3.1)
class DepositGuaranteeAddPage extends StatelessWidget {
  const DepositGuaranteeAddPage({super.key, required this.dio});

  final Dio dio;

  @override
  Widget build(BuildContext context) {
    final existingProvider =
        Provider.of<IncomeProvider?>(context, listen: false);
    final child = _DepositGuaranteeAddView(dio: dio);
    if (existingProvider != null) return child;

    return ChangeNotifierProvider(
      create: (_) => IncomeProvider(monneyType: [], incomeType: []),
      child: child,
    );
  }
}

class _DepositGuaranteeAddView extends StatefulWidget {
  const _DepositGuaranteeAddView({required this.dio});

  final Dio dio;

  @override
  State<_DepositGuaranteeAddView> createState() =>
      _DepositGuaranteeAddPageState();
}

class _DepositGuaranteeAddPageState extends State<_DepositGuaranteeAddView> {
  static const _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _docnoCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final _contractCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();

  final _registerLocal = RegisterLocalDataSource();

  DepositRegisterRepositoryOffline get _repo =>
      ServiceLocator.instance.get<DepositRegisterRepositoryOffline>();
  final _budgetDs = BudgetSourceLocalDataSource();

  DateTime _docDate = DateTime.now();
  DateTime? _dueDate;
  String _depositType = 'contract_guarantee';
  String? _budgetSourceId;
  String? _refPartyId;
  bool _saving = false;

  List<BudgetSourceModel> _budgetSources = const [];
  bool _lookupsReady = false;

  String _moneyGroupForType() {
    if (_depositType == 'withholding_tax') return '3';
    if (_depositType == 'contract_guarantee') return '4';
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPage());
  }

  @override
  void dispose() {
    _docnoCtrl.dispose();
    _amountCtrl.dispose();
    _partyCtrl.dispose();
    _contractCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    final income = context.read<IncomeProvider>();
    await Future.wait([
      income.loadMoneyTypes(),
      income.loadIncomeTypes(),
      income.loadBudgetSources(),
    ]);
    await _reloadBudgetSources();
    _applyDefaultIncomeType(income);
    final docDateStr = _docDate.toIso8601String().split('T').first;
    final docno = await income.fetchDocNo(
      tableName: 'income',
      docDate: docDateStr,
    );
    if (!mounted) return;
    setState(() {
      if (docno != null && docno.isNotEmpty) _docnoCtrl.text = docno;
      _lookupsReady = true;
    });
  }

  void _applyDefaultIncomeType(IncomeProvider income) {
    final needle =
        _depositType == 'withholding_tax' ? 'ภาษีหัก' : 'ประกันสัญญา';
    for (final row in income.incomeType) {
      if (row.length >= 2 && row[1].contains(needle)) {
        income.addIncomeTypeCode(row[0]);
        return;
      }
    }
  }

  Future<void> _reloadBudgetSources() async {
    final mg = _moneyGroupForType();
    final all = await _budgetDs.getAllBudgetSources();
    final fy = FiscalYear.currentBuddhist().toString();
    final filtered = all.where((b) {
      if (mg.isNotEmpty && b.refMoneyGroup != mg) return false;
      if (b.fiscalYear == fy) return true;
      return mg.isNotEmpty;
    }).toList();
    if (!mounted) return;
    setState(() {
      _budgetSources = filtered;
      if (_budgetSourceId != null &&
          !filtered.any((e) => e.id == _budgetSourceId)) {
        _budgetSourceId = null;
      }
      if (_budgetSourceId == null && filtered.isNotEmpty) {
        _budgetSourceId = filtered.first.id;
      }
    });
  }

  Future<List<AppDropdownItem<String>>> _loadPartyLookupItems() async {
    final income = context.read<IncomeProvider>();
    final rows = await income.loadPayerPartyRowsLocalForPicker();
    return rows.map((row) {
      final role = (row['role'] ?? 'both').toString().toLowerCase();
      final name = (row['name'] ?? '').toString();
      return AppDropdownItem<String>(
        value: row['id']?.toString() ?? name,
        label: name,
        subtitle: role == 'both'
            ? TransactionUiText.incomePayerRoleBoth
            : TransactionUiText.incomePayerRolePayer,
      );
    }).toList();
  }

  Future<void> _save() async {
    if (!context
        .read<SimpleAuthProvider>()
        .can(PermissionKey.registerDepositCreate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.cannotDelete)),
      );
      return;
    }
    final income = context.read<IncomeProvider>();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TransactionUiText.registerPleaseSignInAgain),
        ),
      );
      return;
    }
    if (_docnoCtrl.text.trim().isEmpty ||
        _amountCtrl.text.trim().isEmpty ||
        _budgetSourceId == null ||
        income.monneyTypeCode.isEmpty ||
        income.incomeTypeCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.registerFieldRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await _repo.receiveWithIncome(
        token: token,
        body: {
          'docno': _docnoCtrl.text.trim(),
          'docdate': _docDate.toIso8601String(),
          'deposit_type': _depositType,
          'amount': _amountCtrl.text.trim(),
          'refbudgetsource': _budgetSourceId,
          'refmoneytype': income.monneyTypeCode,
          'refincometype': income.incomeTypeCode,
          'refuser': userId,
          'refparty': _refPartyId,
          'party_name_snapshot': _partyCtrl.text.trim(),
          'contract_no': _contractCtrl.text.trim(),
          'detail': _detailCtrl.text.trim(),
          'due_date': _dueDate?.toIso8601String(),
          'fiscal_year': FiscalYear.currentBuddhist().toString(),
          'remark': _detailCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      if (res['status'] == 'successfully') {
        final row = res['data'];
        if (row is Map) {
          final m = Map<String, dynamic>.from(row);
          m['income_docno'] ??= res['income_docno'];
          await _registerLocal.upsertDepositFromServer(m);
        } else {
          await _registerLocal.upsertDepositFromServer({
            'id': res['deposit_id'] ?? res['lastid'],
            'docno': _docnoCtrl.text.trim(),
            'docdate': _docDate.toIso8601String(),
            'deposit_type': _depositType,
            'amount': _amountCtrl.text.trim(),
            'party_name_snapshot': _partyCtrl.text.trim(),
            'contract_no': _contractCtrl.text.trim(),
            'detail': _detailCtrl.text.trim(),
            'due_date': _dueDate?.toIso8601String(),
            'status': 'holding',
            'fiscal_year': FiscalYear.currentBuddhist().toString(),
            'ref_income_id': res['income_id'],
            'income_docno': res['income_docno'] ?? _docnoCtrl.text.trim(),
          });
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(TransactionUiText.registerDepositSaveSuccess),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? TransactionUiText.createFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${TransactionUiText.createFailed}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final income = context.watch<IncomeProvider>();

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          backgroundColor: c.cardWhite,
          foregroundColor: c.textPrimary,
          title: const Text(
            TransactionUiText.registerDepositAddPageTitle,
            style:
                TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.help_outline_rounded,
                size: 20,
                color: c.textSecondary,
              ),
              tooltip: TransactionUiText.registerDepositAddPageGuideTitle,
              onPressed: _showPageGuideDialog,
            ),
            AppBarActionButton(
              label: TransactionUiText.save,
              onPressed: _saving ? null : _save,
              isLoading: _saving,
              isEnabled: !_saving,
              isPrimary: true,
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.cardBorder),
          ),
        ),
        body: !_lookupsReady
            ? const Center(child: CircularProgressIndicator())
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
                          iconColor: c.navy,
                          iconBgColor: c.iconBgLoan,
                          title: TransactionUiText.registerDepositAddPageTitle,
                          subtitle: TransactionUiText.reviewBeforeSave,
                          quickHint: TransactionUiText
                              .registerDepositRequiredBeforeSaveHint,
                          hintAccentColor: c.navy,
                          hintBorderColor: c.cardBorder,
                          textPrimaryColor: c.textPrimary,
                          showQuickHint: false,
                        ),
                        const SizedBox(height: AppTheme.sp16),
                        _card(
                          c,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppDropdownField<String>(
                                label: TransactionUiText.registerDepositColType,
                                value: _depositType,
                                items: const [
                                  AppDropdownItem(
                                    value: 'contract_guarantee',
                                    label: TransactionUiText
                                        .registerDepositTypeContractGuarantee,
                                  ),
                                  AppDropdownItem(
                                    value: 'withholding_tax',
                                    label: TransactionUiText
                                        .registerDepositTypeWithholdingTax,
                                  ),
                                ],
                                onChanged: (v) async {
                                  if (v == null) return;
                                  setState(() => _depositType = v);
                                  _applyDefaultIncomeType(
                                    context.read<IncomeProvider>(),
                                  );
                                  await _reloadBudgetSources();
                                },
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppInput(
                                label: TransactionUiText.date,
                                action: AppInputAction.date(
                                  initialValue: _docDate,
                                  onChanged: (d) {
                                    if (d != null) setState(() => _docDate = d);
                                  },
                                ),
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppInput(
                                label: TransactionUiText.docNumber,
                                controller: _docnoCtrl,
                                action: const AppInputAction.text(),
                                required: true,
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppInput(
                                label: TransactionUiText.amount,
                                controller: _amountCtrl,
                                action: const AppInputAction.number(
                                  allowDecimal: true,
                                ),
                                textAlign: TextAlign.right,
                                required: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        _card(
                          c,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppLookupPickerField<String>(
                                label: TransactionUiText
                                    .registerDepositIncomeTypeLabel,
                                value: income.incomeTypeCode.isEmpty
                                    ? null
                                    : income.incomeTypeCode,
                                clearable: false,
                                items: income.incomeType
                                    .map(
                                      (row) => AppDropdownItem(
                                        value: row[0],
                                        label: row[1],
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) income.addIncomeTypeCode(v);
                                },
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              if (_budgetSources.isEmpty)
                                Text(
                                  TransactionUiText
                                      .registerDepositNoBudgetSource,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontFamily: _fontFamily,
                                  ),
                                )
                              else
                                AppLookupPickerField<String>(
                                  label: TransactionUiText
                                      .registerDepositBudgetSourceLabel,
                                  value: _budgetSourceId,
                                  clearable: false,
                                  items: _budgetSources
                                      .map(
                                        (b) => AppDropdownItem(
                                          value: b.id,
                                          label:
                                              '${b.code} ${b.name} (${b.fiscalYear})',
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _budgetSourceId = v),
                                ),
                              const SizedBox(height: AppTheme.sp12),
                              AppLookupPickerField<String>(
                                label: TransactionUiText
                                    .registerDepositMoneyTypeLabel,
                                value: income.monneyTypeCode.isEmpty
                                    ? null
                                    : income.monneyTypeCode,
                                clearable: false,
                                items: income.monneyType
                                    .map(
                                      (row) => AppDropdownItem(
                                        value: row[0],
                                        label: row[1],
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) income.addMonneyTypeCode(v);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        _card(
                          c,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppLookupPickerField<String>(
                                label:
                                    TransactionUiText.registerDepositPartyLabel,
                                value: _refPartyId,
                                displayLabel: _partyCtrl.text.trim().isEmpty
                                    ? null
                                    : _partyCtrl.text.trim(),
                                clearable: false,
                                pickerTitle:
                                    TransactionUiText.incomePayerPickerTitle,
                                searchHint: TransactionUiText
                                    .incomePayerPickerSearchHint,
                                loadingText:
                                    TransactionUiText.incomePayerPickerLoading,
                                emptyText: TransactionUiText
                                    .receiveFromNoPayerDialogBody,
                                loadItems: _loadPartyLookupItems,
                                onChanged: (v) async {
                                  final id = v?.trim() ?? '';
                                  if (id.isEmpty) return;
                                  final items = await _loadPartyLookupItems();
                                  final selected = items
                                      .cast<AppDropdownItem<String>?>()
                                      .firstWhere(
                                        (item) => item?.value == id,
                                        orElse: () => null,
                                      );
                                  if (!mounted || selected == null) return;
                                  setState(() {
                                    _refPartyId = id;
                                    _partyCtrl.text = selected.label;
                                  });
                                },
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppInput(
                                label: TransactionUiText
                                    .registerDepositContractNoLabel,
                                controller: _contractCtrl,
                                action: const AppInputAction.text(),
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppInput(
                                label: TransactionUiText.registerDepositColDue,
                                action: AppInputAction.date(
                                  initialValue: _dueDate,
                                  onChanged: (d) =>
                                      setState(() => _dueDate = d),
                                ),
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppInput(
                                label: TransactionUiText.detail,
                                controller: _detailCtrl,
                                action: const AppInputAction.text(),
                                minLines: 2,
                                maxLines: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.sp24),
                      ],
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
      title: TransactionUiText.registerDepositAddPageGuideTitle,
      items: [
        PageGuideItem(
          icon: Icons.account_balance_wallet_outlined,
          text: TransactionUiText.registerDepositRequiredBeforeSaveHint,
          accentColor: c.navy,
          backgroundColor: c.iconBgLoan,
        ),
        PageGuideItem(
          icon: Icons.info_outline_rounded,
          text: TransactionUiText.registerDepositLinkedIncomeHint,
          accentColor: c.navy,
          backgroundColor: c.iconBgLoan,
        ),
      ],
    );
  }

  Widget _card(AppColors c, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: child,
    );
  }
}
