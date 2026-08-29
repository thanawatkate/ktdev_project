import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/expense/presentation/providers/expense_provider.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/register/data/repositories/deposit_register_repository_offline.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// คืน/นำส่ง/ริบ เงินประกัน — บันทึกทะเบียน + ใบจ่าย
class DepositGuaranteeSettlePage extends StatelessWidget {
  const DepositGuaranteeSettlePage({
    super.key,
    required this.dio,
    required this.deposit,
  });

  final Dio dio;
  final Map<String, dynamic> deposit;

  @override
  Widget build(BuildContext context) {
    final existingProvider =
        Provider.of<ExpenseProvider?>(context, listen: false);
    final child = _DepositGuaranteeSettleView(
      dio: dio,
      deposit: deposit,
    );
    if (existingProvider != null) return child;

    return ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: child,
    );
  }
}

class _DepositGuaranteeSettleView extends StatefulWidget {
  const _DepositGuaranteeSettleView({
    required this.dio,
    required this.deposit,
  });

  final Dio dio;
  final Map<String, dynamic> deposit;

  @override
  State<_DepositGuaranteeSettleView> createState() =>
      _DepositGuaranteeSettlePageState();
}

class _DepositGuaranteeSettlePageState
    extends State<_DepositGuaranteeSettleView> {
  static const _fontFamily = 'Kanit';
  static const double _maxResponsiveFormWidth = 1440;

  final _settledDocnoCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  final _registerLocal = RegisterLocalDataSource();

  DepositRegisterRepositoryOffline get _repo =>
      ServiceLocator.instance.get<DepositRegisterRepositoryOffline>();

  String _settleType = 'returned';
  bool _saving = false;
  bool _lookupsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLookups());
  }

  @override
  void dispose() {
    _settledDocnoCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLookups() async {
    final expense = context.read<ExpenseProvider>();
    await expense.loadExpenseTypes();
    if (expense.expenseTypes.isNotEmpty) {
      expense.addExpenseTypeCode(expense.expenseTypes.first[0]);
    }
    await Future.wait([
      expense.loadMoneyTypes(),
      expense.loadBudgetSources(),
    ]);
    final docDate = DateTime.now().toIso8601String().split('T').first;
    final docno = await expense.fetchDocNo(
      tableName: 'expense',
      docDate: docDate,
    );
    if (!mounted) return;
    setState(() {
      if (docno != null && docno.isNotEmpty) _settledDocnoCtrl.text = docno;
      _lookupsReady = true;
    });
  }

  Future<void> _save() async {
    if (!context
        .read<SimpleAuthProvider>()
        .can(PermissionKey.registerDepositSettle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.cannotDelete)),
      );
      return;
    }
    final expense = context.read<ExpenseProvider>();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TransactionUiText.registerPleaseSignInAgain),
        ),
      );
      return;
    }
    if (expense.budgetSourceCode.isEmpty || expense.moneyTypeCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TransactionUiText.registerFieldRequired)),
      );
      return;
    }

    final idStr = widget.deposit['id']?.toString() ?? '';
    final serverId = int.tryParse(idStr);
    if (serverId == null && !idStr.startsWith('local_deposit_')) return;

    setState(() => _saving = true);
    try {
      final res = await _repo.returnWithExpense(
        serverOrLocalId: serverId ?? 0,
        localIdHint: idStr,
        token: token,
        body: {
          'status': _settleType,
          'settled_docno': _settledDocnoCtrl.text.trim(),
          'settled_remark': _remarkCtrl.text.trim(),
          'refbudgetsource': expense.budgetSourceCode,
          'refmoneytype': expense.moneyTypeCode,
          'amount': widget.deposit['amount'],
          'expense_docno': _settledDocnoCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      if (res['status'] == 'successfully') {
        final row = res['data'];
        if (row is Map) {
          final m = Map<String, dynamic>.from(row);
          m['expense_docno'] ??= res['expense_docno'];
          await _registerLocal.upsertDepositFromServer(m);
        } else {
          await _registerLocal.upsertDepositFromServer({
            ...widget.deposit,
            'id': idStr,
            'status': _settleType,
            'settled_docno': _settledDocnoCtrl.text.trim(),
            'settled_remark': _remarkCtrl.text.trim(),
            'ref_expense_id': res['expense_id'],
            'expense_docno':
                res['expense_docno'] ?? _settledDocnoCtrl.text.trim(),
          });
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(TransactionUiText.registerDepositSettleSuccess),
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
    final expense = context.watch<ExpenseProvider>();

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          toolbarHeight: 52,
          backgroundColor: c.cardWhite,
          foregroundColor: c.textPrimary,
          title: const Text(
            TransactionUiText.registerDepositSettlePageTitle,
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
              tooltip: TransactionUiText.registerDepositSettlePageGuideTitle,
              onPressed: _showPageGuideDialog,
            ),
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
                          icon: Icons.undo_rounded,
                          iconColor: c.navy,
                          iconBgColor: c.iconBgLoan,
                          title:
                              TransactionUiText.registerDepositSettlePageTitle,
                          subtitle: TransactionUiText.reviewBeforeSave,
                          quickHint: TransactionUiText
                              .registerDepositSettleRequiredBeforeSaveHint,
                          hintAccentColor: c.navy,
                          hintBorderColor: c.cardBorder,
                          textPrimaryColor: c.textPrimary,
                          showQuickHint: false,
                        ),
                        const SizedBox(height: AppTheme.sp16),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.sp16),
                          decoration: BoxDecoration(
                            color: c.cardWhite,
                            borderRadius: BorderRadius.circular(AppTheme.r16),
                            border: Border.all(color: c.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppDropdownField<String>(
                                label: TransactionUiText
                                    .registerDepositSettleAction,
                                value: _settleType,
                                items: const [
                                  AppDropdownItem(
                                    value: 'returned',
                                    label: TransactionUiText
                                        .registerDepositSettleReturned,
                                  ),
                                  AppDropdownItem(
                                    value: 'submitted',
                                    label: TransactionUiText
                                        .registerDepositSettleSubmitted,
                                  ),
                                  AppDropdownItem(
                                    value: 'forfeited',
                                    label: TransactionUiText
                                        .registerDepositSettleForfeited,
                                  ),
                                ],
                                onChanged: (v) => setState(
                                    () => _settleType = v ?? _settleType),
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppInput(
                                label: TransactionUiText
                                    .registerDepositSettledDocNo,
                                controller: _settledDocnoCtrl,
                                action: const AppInputAction.text(),
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppLookupPickerField<String>(
                                label: TransactionUiText
                                    .registerDepositBudgetSourceLabel,
                                value: expense.budgetSourceCode.isEmpty
                                    ? null
                                    : expense.budgetSourceCode,
                                clearable: false,
                                items: expense.budgetSource
                                    .map(
                                      (row) => AppDropdownItem(
                                        value: row[0],
                                        label: row[1],
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) expense.addBudgetSourceCode(v);
                                },
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppLookupPickerField<String>(
                                label: TransactionUiText
                                    .registerDepositMoneyTypeLabel,
                                value: expense.moneyTypeCode.isEmpty
                                    ? null
                                    : expense.moneyTypeCode,
                                clearable: false,
                                items: expense.moneyTypes
                                    .map(
                                      (row) => AppDropdownItem(
                                        value: row[0],
                                        label: row[1],
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) expense.addMoneyTypeCode(v);
                                },
                              ),
                              const SizedBox(height: AppTheme.sp12),
                              AppInput(
                                label: TransactionUiText.remark,
                                controller: _remarkCtrl,
                                action: const AppInputAction.text(),
                                minLines: 2,
                                maxLines: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.sp24),
                        AppButton.primary(
                          label: TransactionUiText.save,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          isLoading: _saving,
                          onPressed: _saving ? null : _save,
                        ),
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
    final docno = widget.deposit['docno']?.toString() ?? '-';
    final amount = widget.deposit['amount']?.toString() ?? '-';
    await PageGuideDialog.show(
      context: context,
      title: TransactionUiText.registerDepositSettlePageGuideTitle,
      items: [
        PageGuideItem(
          icon: Icons.undo_rounded,
          text: TransactionUiText.registerDepositSettleRequiredBeforeSaveHint,
          accentColor: c.navy,
          backgroundColor: c.iconBgLoan,
        ),
        PageGuideItem(
          icon: Icons.receipt_long_outlined,
          text:
              '$docno · $amount ${TransactionUiText.baht}\n${TransactionUiText.registerDepositLinkedExpenseHint}',
          accentColor: c.navy,
          backgroundColor: c.iconBgLoan,
        ),
      ],
    );
  }
}
