import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/forms/data/datasources/form_local_data_source.dart';
import 'package:saccm/widgets/widgets.dart';
import 'form_bottom_sheet_layout.dart';

class VoucherReceiveForm extends StatefulWidget {
  const VoucherReceiveForm({
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
  State<VoucherReceiveForm> createState() => _VoucherReceiveFormState();
}

class _VoucherReceiveFormState extends State<VoucherReceiveForm> {
  final _docno = TextEditingController();
  DateTime? _docDate = DateTime.now();
  final _receiverName = TextEditingController();
  final _receiverAddress = TextEditingController();
  final _payerName = TextEditingController();
  String? _payerUserId;
  final _detail = TextEditingController();
  final _amount = TextEditingController();
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

  @override
  void dispose() {
    _docno.dispose();
    _receiverName.dispose();
    _receiverAddress.dispose();
    _payerName.dispose();
    _detail.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormBottomSheetLayout(
      title: TransactionUiText.formsCardVoucherReceiveTitle,
      icon: Icons.receipt_outlined,
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
          controller: _receiverName,
          label: TransactionUiText.formsLabelReceiverName,
        ),
        AppInput(
          controller: _receiverAddress,
          label: TransactionUiText.formsLabelReceiverAddress,
        ),
        AppInput(
          controller: _detail,
          label: TransactionUiText.formsLabelExpenseDetail,
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
        AppInput(
          controller: _payerName,
          label: TransactionUiText.formsLabelPayer,
        ),
        if (widget.personnelOptions.isNotEmpty)
          AppLookupPickerField<String>(
            label: TransactionUiText.formsLabelSelectPayerFromDb,
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
      ],
      validateBeforeSubmit: () {
        if (_docno.text.trim().isEmpty ||
            _receiverName.text.trim().isEmpty ||
            _receiverAddress.text.trim().isEmpty ||
            _detail.text.trim().isEmpty ||
            _payerName.text.trim().isEmpty ||
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
          'docno': _docno.text.trim(),
          'docdate': _docDate != null
              ? DateFormat('yyyy-MM-dd').format(_docDate!)
              : '',
          'receiver_name': _receiverName.text.trim(),
          'receiver_address': _receiverAddress.text.trim(),
          'payer_user_id': _payerUserId,
          'payer_name': _payerName.text.trim(),
          'detail': _detail.text.trim(),
          'amount': double.tryParse(_amount.text.trim()) ?? 0,
        });
      },
    );
  }
}
