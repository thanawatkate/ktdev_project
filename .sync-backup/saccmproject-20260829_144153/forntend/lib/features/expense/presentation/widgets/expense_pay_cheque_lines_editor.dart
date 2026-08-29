import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/cheque_account/presentation/pages/cheque_account_page.dart';
import 'package:saccm/features/expense/presentation/providers/expense_provider.dart';
import 'package:saccm/widgets/widgets.dart';

/// หนึ่งแถวเช็คในฟอร์มรายจ่าย
class PayChequeLineControllers {
  PayChequeLineControllers({
    this.accountId = '',
    String chequeno = '',
    String amount = '',
  })  : chequenoCtrl = TextEditingController(text: chequeno),
        amountCtrl = TextEditingController(text: amount);

  String accountId;
  final TextEditingController chequenoCtrl;
  final TextEditingController amountCtrl;

  void dispose() {
    chequenoCtrl.dispose();
    amountCtrl.dispose();
  }
}

/// แก้ไขหลายใบเช็คต่อหนึ่งใบรายจ่าย
class ExpensePayChequeLinesEditor extends StatefulWidget {
  const ExpensePayChequeLinesEditor({
    super.key,
    required this.provider,
    required this.expenseTotal,
    this.initialRows,
    this.onChanged,
  });

  final ExpenseProvider provider;
  final double expenseTotal;
  final List<Map<String, dynamic>>? initialRows;
  final VoidCallback? onChanged;

  @override
  ExpensePayChequeLinesEditorState createState() =>
      ExpensePayChequeLinesEditorState();
}

class ExpensePayChequeLinesEditorState
    extends State<ExpensePayChequeLinesEditor> {
  final List<PayChequeLineControllers> _lines = [];

  @override
  void initState() {
    super.initState();
    _reloadLines(widget.initialRows);
  }

  void _reloadLines(List<Map<String, dynamic>>? initial) {
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();
    if (initial != null && initial.isNotEmpty) {
      for (final r in initial) {
        final line = PayChequeLineControllers(
          accountId: r['refChequeAccount']?.toString() ??
              r['refchequeaccount']?.toString() ??
              '',
          chequeno: r['chequeno']?.toString() ?? '',
          amount: r['chequeamount']?.toString() ?? '',
        );
        line.chequenoCtrl.addListener(_notify);
        line.amountCtrl.addListener(_notify);
        _lines.add(line);
      }
    } else {
      final line = PayChequeLineControllers();
      if (widget.expenseTotal > 0) {
        line.amountCtrl.text = widget.expenseTotal.toStringAsFixed(2);
      }
      line.chequenoCtrl.addListener(_notify);
      line.amountCtrl.addListener(_notify);
      _lines.add(line);
    }
  }

  @override
  void didUpdateWidget(covariant ExpensePayChequeLinesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSig = _rowsSignature(oldWidget.initialRows);
    final newSig = _rowsSignature(widget.initialRows);
    if (oldSig != newSig &&
        widget.initialRows != null &&
        widget.initialRows!.isNotEmpty) {
      _reloadLines(widget.initialRows);
      if (mounted) setState(() {});
    }
  }

  String _rowsSignature(List<Map<String, dynamic>>? rows) {
    if (rows == null || rows.isEmpty) return '';
    return rows
        .map((r) => '${r['id']}|${r['chequeno']}|${r['chequeamount']}')
        .join(';');
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged?.call();
    if (mounted) setState(() {});
  }

  double get _linesSum {
    var s = 0.0;
    for (final l in _lines) {
      s += _parse(l.amountCtrl.text);
    }
    return s;
  }

  double _parse(String raw) {
    final n = double.tryParse(raw.replaceAll(',', '').trim());
    return n ?? 0;
  }

  void _addLine() {
    setState(() {
      final line = PayChequeLineControllers();
      line.chequenoCtrl.addListener(_notify);
      line.amountCtrl.addListener(_notify);
      _lines.add(line);
    });
    _notify();
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines.removeAt(index).dispose();
    });
    _notify();
  }

  void _fillRemainder(int index) {
    var used = 0.0;
    for (var i = 0; i < _lines.length; i++) {
      if (i != index) used += _parse(_lines[i].amountCtrl.text);
    }
    final rest = widget.expenseTotal - used;
    _lines[index].amountCtrl.text = rest > 0 ? rest.toStringAsFixed(2) : '0.00';
    _notify();
  }

  List<Map<String, dynamic>> buildPayload({String remark = ''}) {
    return _lines
        .where((l) =>
            l.accountId.isNotEmpty ||
            l.chequenoCtrl.text.trim().isNotEmpty ||
            _parse(l.amountCtrl.text) > 0)
        .map(
          (l) => <String, dynamic>{
            'chequeamount': _parse(l.amountCtrl.text).toStringAsFixed(2),
            'refchequeaccount': l.accountId,
            'chequeno': l.chequenoCtrl.text.trim(),
            'remark': remark,
          },
        )
        .toList();
  }

  String snapshot() {
    return _lines
        .map(
            (l) => '${l.accountId}|${l.chequenoCtrl.text}|${l.amountCtrl.text}')
        .join(';');
  }

  String? validate() {
    if (widget.provider.chequeAccounts.isEmpty) {
      return TransactionUiText.expenseChequeNoAccountHint;
    }
    if (_lines.isEmpty) {
      return TransactionUiText.expenseChequeFillNo;
    }
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.accountId.isEmpty) {
        return TransactionUiText.expenseChequeSelectAccount;
      }
      if (l.chequenoCtrl.text.trim().isEmpty) {
        return TransactionUiText.expenseChequeFillNo;
      }
      if (_parse(l.amountCtrl.text) <= 0) {
        return TransactionUiText.amountMustPositive;
      }
    }
    final total = widget.expenseTotal;
    if (total > 0 && (_linesSum - total).abs() > 0.01) {
      return TransactionUiText.expenseChequeSumMismatch;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasAccounts = widget.provider.chequeAccounts.isNotEmpty;
    final sumMismatch = widget.expenseTotal > 0 &&
        (_linesSum - widget.expenseTotal).abs() > 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasAccounts) ...[
          Text(
            TransactionUiText.expenseChequeNoAccountHint,
            style: TextStyle(color: c.expenseRed, fontSize: 13),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChequeAccountPage(),
                  ),
                );
                await widget.provider.loadChequeAccounts();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.add_card_outlined, size: 18),
              label: const Text(TransactionUiText.chequeAccountAdd),
            ),
          ),
        ],
        ...List.generate(_lines.length, (i) {
          final line = _lines[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i < _lines.length - 1 ? 12 : 0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: c.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${TransactionUiText.expenseChequeLineLabel} ${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_lines.length > 1)
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline,
                                color: c.expenseRed, size: 22),
                            onPressed: () => _removeLine(i),
                            tooltip: TransactionUiText.delete,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppLookupPickerField<String>(
                      label: TransactionUiText.expenseChequeAccountTitle,
                      required: true,
                      enabled: hasAccounts,
                      hint: hasAccounts
                          ? TransactionUiText.expenseChequeSelectAccount
                          : TransactionUiText.expenseChequeNoAccountHint,
                      value: line.accountId.isEmpty ? null : line.accountId,
                      clearable: false,
                      items: widget.provider.chequeAccounts
                          .map(
                            (e) => AppDropdownItem<String>(
                              value: e[0],
                              label: e.length > 1 ? e[1] : e[0],
                            ),
                          )
                          .toList(),
                      onChanged: hasAccounts
                          ? (v) {
                              setState(() => line.accountId = v ?? '');
                              _notify();
                            }
                          : null,
                    ),
                    const SizedBox(height: 8),
                    AppInput(
                      label: TransactionUiText.expenseChequeNoTitle,
                      required: true,
                      controller: line.chequenoCtrl,
                      prefixIcon:
                          const Icon(Icons.confirmation_number_outlined),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppInput(
                            label: TransactionUiText.expenseChequeAmountLabel,
                            required: true,
                            controller: line.amountCtrl,
                            action: const AppInputAction.number(
                              allowDecimal: true,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: TextButton(
                            onPressed: () => _fillRemainder(i),
                            child: const Text(
                              TransactionUiText.expenseChequeFillRemainder,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: hasAccounts ? _addLine : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text(TransactionUiText.expenseChequeAddLine),
        ),
        if (sumMismatch) ...[
          const SizedBox(height: 8),
          Text(
            TransactionUiText.expenseChequeSumMismatchDetail(
              _linesSum,
              widget.expenseTotal,
            ),
            style: TextStyle(color: c.expenseRed, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
