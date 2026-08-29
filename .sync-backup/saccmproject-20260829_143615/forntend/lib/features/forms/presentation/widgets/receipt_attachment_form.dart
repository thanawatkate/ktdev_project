import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/forms/data/datasources/form_local_data_source.dart';
import 'package:saccm/widgets/widgets.dart';
import 'form_bottom_sheet_layout.dart';

class ReceiptAttachmentForm extends StatefulWidget {
  const ReceiptAttachmentForm({
    super.key,
    this.initialDocNo,
    this.allowManualDocNoOverride = true,
    this.personnelOptions = const [],
    this.onGenerateDocNo,
  });

  final String? initialDocNo;
  final bool allowManualDocNoOverride;
  final List<FormPersonnelOption> personnelOptions;
  final Future<String?> Function(DateTime? docDate)? onGenerateDocNo;

  @override
  State<ReceiptAttachmentForm> createState() => _ReceiptAttachmentFormState();
}

class _ReceiptAttachmentFormState extends State<ReceiptAttachmentForm> {
  final _docno = TextEditingController();
  DateTime? _docDate = DateTime.now();
  final _subject = TextEditingController();
  final _preparer = TextEditingController();
  String? _preparerUserId;
  final List<_LineItem> _items = [_LineItem()];
  bool _isGeneratingDocNo = false;

  @override
  void initState() {
    super.initState();
    _docno.text = widget.initialDocNo?.trim() ?? '';
  }

  Future<void> _regenerateDocNo() async {
    if (widget.onGenerateDocNo == null || _isGeneratingDocNo) return;
    setState(() => _isGeneratingDocNo = true);
    final docNo = await widget.onGenerateDocNo!.call(_docDate);
    if (!mounted) return;
    if (docNo != null && docNo.trim().isNotEmpty) {
      setState(() => _docno.text = docNo.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(TransactionUiText.formsDocNoGenerateFailed)),
      );
    }
    setState(() => _isGeneratingDocNo = false);
  }

  void _addLine() => setState(() => _items.add(_LineItem()));
  void _removeLine(int i) => setState(() {
        final removed = _items.removeAt(i);
        removed.dispose();
      });

  @override
  void dispose() {
    _docno.dispose();
    _subject.dispose();
    _preparer.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormBottomSheetLayout(
      title: TransactionUiText.formsCardReceiptAttachmentTitle,
      icon: Icons.attach_file_outlined,
      sectionTitle: TransactionUiText.formsSectionDocumentInfo,
      children: [
        AppInput(
          controller: _docno,
          label: TransactionUiText.formsLabelDocNo,
          readOnly: !widget.allowManualDocNoOverride,
          helperText: widget.allowManualDocNoOverride
              ? null
              : TransactionUiText.formsDocNoAutoOnlyHint,
          action: AppInputAction.text(
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGeneratingDocNo)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: TransactionUiText.formsRegenerateDocNoTooltip,
                    onPressed: _regenerateDocNo,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
          ),
        ),
        AppInput(
          label: TransactionUiText.formsLabelDate,
          action: AppInputAction.date(
            initialValue: _docDate,
            onChanged: (d) => _docDate = d,
          ),
        ),
        AppInput(
          controller: _subject,
          label: TransactionUiText.formsLabelSubject,
        ),
        const Divider(),
        const Text(
          TransactionUiText.formsSectionReceiptList,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final it = entry.value;
          return Row(
            children: [
              SizedBox(
                width: 110,
                child: AppInput(
                  controller: it.receiptNo,
                  label: TransactionUiText.formsLabelReceiptNo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppInput(
                  controller: it.detail,
                  label: TransactionUiText.formsLabelDetail,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: AppInput(
                  controller: it.amount,
                  label: TransactionUiText.formsLabelAmount,
                  action: const AppInputAction.number(allowDecimal: true),
                  textAlign: TextAlign.right,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _items.length > 1 ? () => _removeLine(i) : null,
              ),
            ],
          );
        }),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add),
            label: const Text(TransactionUiText.formsAddRow),
          ),
        ),
        AppInput(
          controller: _preparer,
          label: TransactionUiText.formsLabelPreparerName,
        ),
        if (widget.personnelOptions.isNotEmpty)
          AppLookupPickerField<String>(
            label: TransactionUiText.formsLabelSelectPreparerFromDb,
            value: _preparerUserId,
            displayLabel:
                _preparer.text.trim().isEmpty ? null : _preparer.text.trim(),
            clearable: false,
            items: widget.personnelOptions
                .map(
                  (e) => AppDropdownItem<String>(
                    value: e.id,
                    label: e.fullName,
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              FormPersonnelOption? selected;
              for (final option in widget.personnelOptions) {
                if (option.id == v) {
                  selected = option;
                  break;
                }
              }
              if (selected == null) return;
              final selectedName = selected.fullName;
              final selectedId = selected.id;
              setState(() {
                _preparer.text = selectedName;
                _preparerUserId = selectedId;
              });
            },
          ),
      ],
      validateBeforeSubmit: () {
        if (_docno.text.trim().isEmpty ||
            _subject.text.trim().isEmpty ||
            _preparer.text.trim().isEmpty ||
            _docDate == null) {
          return TransactionUiText.formsValidationPleaseFillRequired;
        }
        if (_items.isEmpty) {
          return TransactionUiText.formsValidationAtLeastOneReceiptItem;
        }
        for (final item in _items) {
          final amount = double.tryParse(item.amount.text.trim()) ?? 0;
          if (item.receiptNo.text.trim().isEmpty ||
              item.detail.text.trim().isEmpty ||
              amount <= 0) {
            return TransactionUiText.formsValidationReceiptItemIncomplete;
          }
        }
        return null;
      },
      onSubmit: () {
        final items = _items
            .map((it) => {
                  'receipt_no': it.receiptNo.text.trim(),
                  'detail': it.detail.text.trim(),
                  'amount': double.tryParse(it.amount.text.trim()) ?? 0,
                })
            .toList();
        Navigator.pop(context, {
          'docno': _docno.text.trim(),
          'docdate': _docDate != null
              ? DateFormat('yyyy-MM-dd').format(_docDate!)
              : '',
          'subject': _subject.text.trim(),
          'preparer_user_id': _preparerUserId,
          'preparer_name': _preparer.text.trim(),
          'items': items,
        });
      },
    );
  }
}

class _LineItem {
  final receiptNo = TextEditingController();
  final detail = TextEditingController();
  final amount = TextEditingController();

  void dispose() {
    receiptNo.dispose();
    detail.dispose();
    amount.dispose();
  }
}
