import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/local_data_source/expense_local_data_source.dart';
import 'package:saccm/features/expense/data/repositories/expense_repository_offline.dart';
import 'package:saccm/features/income/data/repositories/income_repository_offline.dart'
    as income_offline;
import 'package:saccm/features/income/domain/usecases/get_doc_no.dart';
import 'package:saccm/features/loan/data/repositories/repay_loan_repository_offline.dart';
import 'package:saccm/features/loan/presentation/providers/loan_provider.dart';
import 'package:saccm/features/loan/presentation/providers/repay_loan_provider.dart';
import 'package:saccm/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _loanObligation(Map<String, dynamic> row) {
  final principal = double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
  final opening = (row['opening_outstanding'] as num?)?.toDouble() ??
      double.tryParse(row['opening_outstanding']?.toString() ?? '0') ??
      0;
  return principal + opening;
}

double _loanOutstanding(Map<String, dynamic> row) =>
    (row['outstanding'] as num?)?.toDouble() ??
    double.tryParse(row['outstanding']?.toString() ?? '0') ??
    0;

double _loanRepaid(Map<String, dynamic> row) {
  final o = _loanObligation(row);
  final s = _loanOutstanding(row);
  final r = o - s;
  return r > 0 ? r : 0;
}

int _compareLoansForManagement(Map<String, dynamic> a, Map<String, dynamic> b) {
  final ao = a['is_overdue'] == true;
  final bo = b['is_overdue'] == true;
  if (ao != bo) return ao ? -1 : 1;
  final da = DateTime.tryParse(a['duedate']?.toString() ?? '');
  final db = DateTime.tryParse(b['duedate']?.toString() ?? '');
  if (da != null && db != null && da != db) return da.compareTo(db);
  if (da != null && db == null) return -1;
  if (da == null && db != null) return 1;
  return (b['outstanding'] as num?)?.compareTo(a['outstanding'] as num? ?? 0) ??
      0;
}

class LoanManagementPage extends StatelessWidget {
  const LoanManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hasLoanProvider =
        Provider.of<LoanProvider?>(context, listen: false) != null;
    final hasRepayProvider =
        Provider.of<RepayLoanProvider?>(context, listen: false) != null;
    const child = _LoanManagementView();

    if (hasLoanProvider && hasRepayProvider) return child;

    return MultiProvider(
      providers: [
        if (!hasLoanProvider)
          ChangeNotifierProvider(create: (_) => LoanProvider()),
        if (!hasRepayProvider)
          ChangeNotifierProvider(create: (_) => RepayLoanProvider()),
      ],
      child: child,
    );
  }
}

class _LoanManagementView extends StatefulWidget {
  const _LoanManagementView();

  @override
  State<_LoanManagementView> createState() => _LoanManagementPageState();
}

class _LoanManagementPageState extends State<_LoanManagementView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<LoanProvider>().loadLoanList();
      if (!mounted) return;
      await context.read<RepayLoanProvider>().loadRepayLoanList();
    });
  }

  List<Map<String, dynamic>> _outstandingRows(LoanProvider loan) {
    final list = loan.rows
        .where((r) => _loanOutstanding(r) > 0.0001)
        .toList(growable: false);
    list.sort(_compareLoansForManagement);
    return list;
  }

  double _totalOutstanding(List<Map<String, dynamic>> rows) =>
      rows.fold<double>(0, (s, r) => s + _loanOutstanding(r));

  double _repaySumByLoanId(
    RepayLoanProvider repay,
    String loanId, {
    String? excludeRepayId,
    String? serverId,
    String? docno,
  }) {
    final refs = <String>{
      loanId,
      if (serverId != null && serverId.isNotEmpty) serverId,
      if (docno != null && docno.isNotEmpty) docno,
    };
    return repay.rows.fold<double>(0, (sum, row) {
      final refLoan = row['refLoan']?.toString() ?? '';
      final rowId = row['id']?.toString();
      if (!refs.contains(refLoan)) return sum;
      if (excludeRepayId != null && rowId == excludeRepayId) return sum;
      return sum + (double.tryParse(row['amount']?.toString() ?? '0') ?? 0);
    });
  }

  Future<void> _openLoanFlowSheet(
    BuildContext context,
    Map<String, dynamic> row,
  ) async {
    final loan = context.read<LoanProvider>();
    final repay = context.read<RepayLoanProvider>();
    await loan.loadLoanList();
    await repay.loadRepayLoanList();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LoanRepayFlowSheet(
        loanRow: row,
        repaySumByLoanId: (String loanId, {String? excludeRepayId}) =>
            _repaySumByLoanId(
          repay,
          loanId,
          excludeRepayId: excludeRepayId,
          serverId: row['server_id']?.toString(),
          docno: row['docno']?.toString(),
        ),
        loanObligation: _loanObligation(row),
        onRepaySuccess: () async {
          await loan.loadLoanList();
          await repay.loadRepayLoanList();
          if (context.mounted) setState(() {});
        },
      ),
    );
  }

  String _formatDateBrief(String raw) {
    if (raw.trim().isEmpty) return '-';
    return ThaiDateFormatter.format(raw, fallback: raw);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final loan = context.watch<LoanProvider>();
    final rows = _outstandingRows(loan);
    final total = _totalOutstanding(rows);
    final fmt = NumberFormat('#,##0.00');

    return SafeArea(
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(c, fmt, total),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                TransactionUiText.loanManagementBorrowersSection,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: loan.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              TransactionUiText.loanManagementEmptyOutstanding,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: rows.length,
                          itemBuilder: (_, i) => _LoanCard(
                              c: c,
                              row: rows[i],
                              fmt: fmt,
                              onTap: () {
                                _openLoanFlowSheet(context, rows[i]);
                              },
                              formatDue: _formatDateBrief),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors c, NumberFormat fmt, double total) {
    return Container(
      width: double.infinity,
      color: c.cardWhite,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TransactionUiText.loanManagementPageTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TransactionUiText.loanManagementTotalOutstandingTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmt.format(total),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                TransactionUiText.baht,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.c,
    required this.row,
    required this.fmt,
    required this.onTap,
    required this.formatDue,
  });

  final AppColors c;
  final Map<String, dynamic> row;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final String Function(String) formatDue;

  @override
  Widget build(BuildContext context) {
    final borrower = row['borrower']?.toString() ?? 'ΓÇö';
    final docno = row['docno']?.toString() ?? '';
    final due = row['duedate']?.toString() ?? '';
    final obligation = _loanObligation(row);
    final outstanding = _loanOutstanding(row);
    final repaid = _loanRepaid(row);
    final isOverdue = row['is_overdue'] == true;
    final partial = repaid > 0.0001;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.cardBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        borrower,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (partial)
                      _badge(
                        c,
                        TransactionUiText.loanManagementPartiallyRepaidBadge,
                        c.loanAmber,
                      )
                    else
                      _badge(
                        c,
                        TransactionUiText.loanOutstandingBadge,
                        c.navy,
                      ),
                    if (isOverdue) ...[
                      const SizedBox(width: 6),
                      _badge(
                        c,
                        TransactionUiText.loanOverdueBadge,
                        c.expenseRed,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _numBlock(
                        c,
                        TransactionUiText.loanManagementPrincipalShort,
                        fmt.format(obligation),
                      ),
                    ),
                    Expanded(
                      child: _numBlock(
                        c,
                        TransactionUiText.loanManagementRemainingShort,
                        fmt.format(outstanding),
                        emphasize: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${TransactionUiText.loanManagementLoanDocShort}: $docno',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
                Text(
                  '${TransactionUiText.loanDueDate}: ${formatDue(due)}',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(AppColors c, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _numBlock(
    AppColors c,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 17 : 14,
            fontWeight: FontWeight.w800,
            color: emphasize ? c.navy : c.textPrimary,
          ),
        ),
        Text(
          TransactionUiText.baht,
          style: TextStyle(fontSize: 10, color: c.textHint),
        ),
      ],
    );
  }
}

class _LoanRepayFlowSheet extends StatefulWidget {
  const _LoanRepayFlowSheet({
    required this.loanRow,
    required this.repaySumByLoanId,
    required this.loanObligation,
    required this.onRepaySuccess,
  });

  final Map<String, dynamic> loanRow;
  final double Function(String loanId, {String? excludeRepayId})
      repaySumByLoanId;
  final double loanObligation;
  final Future<void> Function() onRepaySuccess;

  @override
  State<_LoanRepayFlowSheet> createState() => _LoanRepayFlowSheetState();
}

class _LoanRepayFlowSheetState extends State<_LoanRepayFlowSheet> {
  int _step = 0;
  bool _useVoucher = false;
  bool _submitting = false;

  final _amountCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _repayDocnoCtrl = TextEditingController();
  DateTime _repayDate = DateTime.now();
  late String _repayDateIso = DateTime.now().toIso8601String();

  String get _docno => widget.loanRow['docno']?.toString() ?? '';
  String get _loanId => widget.loanRow['id']?.toString() ?? '';

  double get _remaining {
    final total = widget.loanObligation;
    final repaid = widget.repaySumByLoanId(_loanId);
    final r = total - repaid;
    return r > 0 ? r : 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillDocno());
  }

  Future<void> _prefillDocno() async {
    final repayRepo = ServiceLocator.instance.get<RepayLoanRepository>();
    final dateStr = _repayDateIso.split('T').first;
    try {
      final doc =
          await repayRepo.getDocNo(tableName: 'repay_loan', docDate: dateStr);
      if (mounted) _repayDocnoCtrl.text = doc;
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    _repayDocnoCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRepayDateChanged(DateTime? d) async {
    if (d == null) return;
    setState(() {
      _repayDate = d;
      _repayDateIso = d.toIso8601String();
    });
    final repayRepo = ServiceLocator.instance.get<RepayLoanRepository>();
    final doc = await repayRepo.getDocNo(
      tableName: 'repay_loan',
      docDate: d.toIso8601String().split('T').first,
    );
    if (mounted) _repayDocnoCtrl.text = doc;
  }

  Future<void> _submit() async {
    final amount =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      _snack(TransactionUiText.amountMustPositive);
      return;
    }
    if (amount > _remaining + 0.0001) {
      _snack(
        TransactionUiText.repayLoanSnackExceedsRemaining(
          '${_remaining.toStringAsFixed(2)} ${TransactionUiText.baht}',
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final repayRepo = ServiceLocator.instance.get<RepayLoanRepository>();
    final expenseRepo = ServiceLocator.instance.get<ExpenseRepository>();
    final incomeRepo =
        ServiceLocator.instance.get<income_offline.IncomeRepository>();
    final expenseDs = ServiceLocator.instance.get<ExpenseLocalDataSource>();

    final repayRemark = [
      if (_remarkCtrl.text.trim().isNotEmpty) _remarkCtrl.text.trim(),
      if (_useVoucher) TransactionUiText.loanManagementRepayMethodVoucher,
    ].join(' ┬╖ ');

    String repayId;
    try {
      repayId = await repayRepo.createRepayLoan(
        token: token,
        docno: _repayDocnoCtrl.text.trim(),
        refLoan: _loanId,
        amount: amount.toString(),
        remark: repayRemark,
        duedate: _repayDateIso,
      );
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
      _snack(e.toString());
      return;
    }

    if (_useVoucher) {
      try {
        final typeRows = await expenseDs.db.query(
          'expense_type',
          columns: ['id'],
          where: 'code = ?',
          whereArgs: ['08'],
          limit: 1,
        );
        if (typeRows.isEmpty) {
          throw StateError(
              TransactionUiText.loanManagementLookupExpenseTypeFailed);
        }
        final refExpenseType = typeRows.first['id']?.toString() ?? '';

        final docDate = _repayDateIso.split('T').first;
        final expDocResult = await GetDocNo(incomeRepo)
            .call(GetDocNoParams(tableName: 'expense', docDate: docDate));
        final expenseDocno = expDocResult.fold(
          (f) => throw StateError(f.message),
          (s) => s,
        );

        final borrower = widget.loanRow['borrower']?.toString() ?? '';
        final refMember = widget.loanRow['ref_member']?.toString() ?? '';
        final detail =
            '${TransactionUiText.loanManagementExpenseDetailPrefix} $_docno';
        final remark = [
          if (_remarkCtrl.text.trim().isNotEmpty) _remarkCtrl.text.trim(),
          TransactionUiText.loanManagementExpenseRemarkSuffix,
        ].join(' ');

        await expenseRepo.createExpense(
          token: token,
          docno: expenseDocno,
          docdate: docDate,
          amount: amount.toString(),
          detail: detail,
          remark: remark,
          partyName: borrower,
          refMember: refMember,
          subData: [
            {
              'refexpensetype': refExpenseType,
              'refmoneytype': 'money_cheque',
              'amount': amount.toString(),
              'remark': remark,
            },
          ],
        );
      } catch (e) {
        try {
          await repayRepo.deleteRepayLoan(
            localId: repayId,
            token: token,
            docno: _repayDocnoCtrl.text.trim(),
          );
        } catch (_) {}
        if (mounted) setState(() => _submitting = false);
        _snack(TransactionUiText.loanManagementRepayExpenseFailed);
        return;
      }
    }

    await widget.onRepaySuccess();
    if (!mounted) return;
    setState(() => _submitting = false);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            TransactionUiText.saveSuccess,
            style: const TextStyle(fontFamily: 'Kanit'),
          ),
        ),
      );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(msg, style: const TextStyle(fontFamily: 'Kanit')),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final borrower = widget.loanRow['borrower']?.toString() ?? 'ΓÇö';
    final fmt = NumberFormat('#,##0.00');

    return SafeArea(
      child: AdaptiveContentSheet(
        title: _step == 0
            ? TransactionUiText.loanManagementDetailSheetTitle
            : TransactionUiText.loanManagementRepaySheetTitle,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.sp16,
            0,
            AppTheme.sp16,
            bottom + AppTheme.sp16,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ...[
                  Text(borrower,
                      style: TextStyle(
                          fontSize: 15,
                          color: c.navy,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    '${TransactionUiText.loanManagementLoanDocShort}: $_docno',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  Text(
                    '${TransactionUiText.loanManagementRemainingShort}: ${fmt.format(_remaining)} ${TransactionUiText.baht}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary),
                  ),
                  const SizedBox(height: 20),
                  AppButton.primary(
                    label: TransactionUiText.loanManagementRepayAction,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    fullWidth: true,
                    onPressed: () => setState(() {
                      _step = 1;
                      _amountCtrl.text =
                          _remaining > 0 ? _remaining.toStringAsFixed(2) : '';
                    }),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(TransactionUiText.cancel),
                  ),
                ] else ...[
                  Text(
                    '$_docno ┬╖ ${fmt.format(_remaining)} ${TransactionUiText.baht}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    label: TransactionUiText.docNumber,
                    readOnly: true,
                    controller: _repayDocnoCtrl,
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                  const SizedBox(height: AppTheme.sp8),
                  AppInput(
                    action: AppInputAction.date(
                      initialValue: _repayDate,
                      onChanged: _onRepayDateChanged,
                    ),
                    label: TransactionUiText.date,
                  ),
                  const SizedBox(height: AppTheme.sp8),
                  AppInput(
                    label: TransactionUiText.amount,
                    required: true,
                    controller: _amountCtrl,
                    action: const AppInputAction.number(allowDecimal: true),
                    textAlign: TextAlign.right,
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                  ),
                  const SizedBox(height: AppTheme.sp8),
                  AppInput(
                    label: TransactionUiText.remark,
                    controller: _remarkCtrl,
                    minLines: 1,
                    maxLines: 3,
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    TransactionUiText.loanManagementRepayMethodLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _MethodChip(
                          c: c,
                          selected: !_useVoucher,
                          label:
                              TransactionUiText.loanManagementRepayMethodCash,
                          onTap: () => setState(() => _useVoucher = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MethodChip(
                          c: c,
                          selected: _useVoucher,
                          label: TransactionUiText
                              .loanManagementRepayMethodVoucher,
                          onTap: () => setState(() => _useVoucher = true),
                        ),
                      ),
                    ],
                  ),
                  if (_useVoucher)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        TransactionUiText.loanManagementRepayMethodVoucherHint,
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _step = 0),
                        child: Text(TransactionUiText.back),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 150,
                        child: AppButton.primary(
                          label: TransactionUiText.save,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          isLoading: _submitting,
                          onPressed: _submitting ? null : _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.c,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final AppColors c;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? c.navy.withValues(alpha: 0.1) : c.surface,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: selected ? c.navy : c.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? c.navy : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
