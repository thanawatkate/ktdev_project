import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/forms/data/datasources/form_local_data_source.dart';
import 'package:saccm/widgets/widgets.dart';
import 'form_bottom_sheet_layout.dart';

class WithholdingTaxForm extends StatefulWidget {
  const WithholdingTaxForm({
    super.key,
    this.personnelOptions = const [],
  });

  final List<FormPersonnelOption> personnelOptions;

  @override
  State<WithholdingTaxForm> createState() => _WithholdingTaxFormState();
}

class _WithholdingTaxFormState extends State<WithholdingTaxForm> {
  final _payeeName = TextEditingController();
  final _payeeTaxId = TextEditingController();
  final _payeeAddress = TextEditingController();
  DateTime? _docDate = DateTime.now();
  final _gross = TextEditingController();
  final _tax = TextEditingController();
  final _kind = TextEditingController();
  final _signer = TextEditingController();
  String? _signerUserId;

  @override
  void initState() {
    super.initState();
    _kind.text = 'ค่าจ้างทำของ';
  }

  @override
  void dispose() {
    _payeeName.dispose();
    _payeeTaxId.dispose();
    _payeeAddress.dispose();
    _gross.dispose();
    _tax.dispose();
    _kind.dispose();
    _signer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormBottomSheetLayout(
      title: TransactionUiText.formsCardWithholdingTaxTitle,
      icon: Icons.account_balance_outlined,
      sectionTitle: TransactionUiText.formsSectionDocumentInfo,
      children: [
        AppInput(
          controller: _payeeName,
          label: TransactionUiText.formsLabelPayeeName,
        ),
        AppInput(
          controller: _payeeTaxId,
          label: TransactionUiText.formsLabelPayeeTaxId,
        ),
        AppInput(
          controller: _payeeAddress,
          label: TransactionUiText.formsLabelAddress,
        ),
        AppInput(
          label: TransactionUiText.formsLabelDate,
          action: AppInputAction.date(
            initialValue: _docDate,
            onChanged: (d) => _docDate = d,
          ),
        ),
        AppInput(
          controller: _kind,
          label: TransactionUiText.formsLabelIncomeKind,
        ),
        AppInput(
          controller: _gross,
          label: TransactionUiText.formsLabelGrossAmount,
          action: const AppInputAction.number(allowDecimal: true),
          textAlign: TextAlign.right,
        ),
        AppInput(
          controller: _tax,
          label: TransactionUiText.formsLabelTaxAmount,
          action: const AppInputAction.number(allowDecimal: true),
          textAlign: TextAlign.right,
        ),
        AppInput(
          controller: _signer,
          label: TransactionUiText.formsLabelSigner,
        ),
        if (widget.personnelOptions.isNotEmpty)
          AppLookupPickerField<String>(
            label: TransactionUiText.formsLabelSelectSignerFromDb,
            value: _signerUserId,
            displayLabel:
                _signer.text.trim().isEmpty ? null : _signer.text.trim(),
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
                _signer.text = selectedName;
                _signerUserId = selectedId;
              });
            },
          ),
      ],
      validateBeforeSubmit: () {
        if (_payeeName.text.trim().isEmpty ||
            _payeeTaxId.text.trim().isEmpty ||
            _payeeAddress.text.trim().isEmpty ||
            _kind.text.trim().isEmpty ||
            _signer.text.trim().isEmpty ||
            _docDate == null) {
          return TransactionUiText.formsValidationPleaseFillRequired;
        }
        final gross = double.tryParse(_gross.text.trim()) ?? 0;
        final tax = double.tryParse(_tax.text.trim()) ?? 0;
        if (gross <= 0 || tax <= 0) {
          return TransactionUiText.formsValidationAmountMustBePositive;
        }
        return null;
      },
      onSubmit: () {
        Navigator.pop(context, {
          'payee_name': _payeeName.text.trim(),
          'payee_taxid': _payeeTaxId.text.trim(),
          'payee_address': _payeeAddress.text.trim(),
          'docdate': _docDate != null
              ? DateFormat('yyyy-MM-dd').format(_docDate!)
              : '',
          'income_kind': _kind.text.trim(),
          'gross_amount': double.tryParse(_gross.text.trim()) ?? 0,
          'tax_amount': double.tryParse(_tax.text.trim()) ?? 0,
          'signer_user_id': _signerUserId,
          'signer_name': _signer.text.trim(),
        });
      },
    );
  }
}
