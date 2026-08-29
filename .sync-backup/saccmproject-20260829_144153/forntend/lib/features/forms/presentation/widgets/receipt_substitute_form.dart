import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/forms/data/datasources/form_local_data_source.dart';
import 'package:saccm/widgets/widgets.dart';
import 'form_bottom_sheet_layout.dart';

class ReceiptSubstituteForm extends StatefulWidget {
  const ReceiptSubstituteForm({
    super.key,
    this.personnelOptions = const [],
  });

  final List<FormPersonnelOption> personnelOptions;

  @override
  State<ReceiptSubstituteForm> createState() => _ReceiptSubstituteFormState();
}

class _ReceiptSubstituteFormState extends State<ReceiptSubstituteForm> {
  final _payerName = TextEditingController();
  final _payerPosition = TextEditingController();
  final _detail = TextEditingController();
  final _amount = TextEditingController();
  DateTime? _docDate = DateTime.now();
  String? _payerUserId;

  @override
  void dispose() {
    _payerName.dispose();
    _payerPosition.dispose();
    _detail.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormBottomSheetLayout(
      title: TransactionUiText.formsCardReceiptSubstituteTitle,
      icon: Icons.receipt_long_outlined,
      sectionTitle: TransactionUiText.formsSectionDocumentInfo,
      children: [
        AppInput(
          controller: _payerName,
          label: TransactionUiText.formsLabelPayerName,
        ),
        if (widget.personnelOptions.isNotEmpty)
          AppLookupPickerField<String>(
            label: TransactionUiText.formsLabelSelectSignerFromDb,
            value: _payerUserId,
            displayLabel:
                _payerName.text.trim().isEmpty ? null : _payerName.text.trim(),
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
                _payerName.text = selectedName;
                _payerUserId = selectedId;
              });
            },
          ),
        AppInput(
          controller: _payerPosition,
          label: TransactionUiText.formsLabelPayerPosition,
        ),
        AppInput(
          label: TransactionUiText.formsLabelDate,
          action: AppInputAction.date(
            initialValue: _docDate,
            onChanged: (d) => _docDate = d,
          ),
        ),
        AppInput(
          controller: _detail,
          label: TransactionUiText.formsLabelDetail,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
        ),
        AppInput(
          controller: _amount,
          label: TransactionUiText.formsLabelAmount,
          action: const AppInputAction.number(allowDecimal: true),
          textAlign: TextAlign.right,
        ),
      ],
      validateBeforeSubmit: () {
        if (_payerName.text.trim().isEmpty ||
            _payerPosition.text.trim().isEmpty ||
            _detail.text.trim().isEmpty ||
            _docDate == null) {
          return TransactionUiText.formsValidationPleaseFillRequired;
        }
        final amount = double.tryParse(_amount.text.trim()) ?? 0;
        if (amount <= 0) {
          return TransactionUiText.formsValidationAmountMustBePositive;
        }
        return null;
      },
      onSubmit: () {
        Navigator.pop(context, {
          'payer_user_id': _payerUserId,
          'payer_name': _payerName.text.trim(),
          'payer_position': _payerPosition.text.trim(),
          'docdate': _docDate != null
              ? DateFormat('yyyy-MM-dd').format(_docDate!)
              : '',
          'detail': _detail.text.trim(),
          'amount': double.tryParse(_amount.text.trim()) ?? 0,
        });
      },
    );
  }
}
