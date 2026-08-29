import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import '../../constants/app_theme.dart';
import '../sheet/adaptive_content_sheet.dart';
import 'app_input_decoration.dart';

/// โหมดการทำงานของช่องปีงบประมาณ พ.ศ. ([BuddhistYearField])
enum BuddhistYearFieldMode {
  /// แบบกรอกข้อมูล — ผู้ใช้พิมพ์ปี พ.ศ. (4 หลัก) ในช่องเอง
  /// และยังสามารถกดปุ่มเปิดรายการช่วยเลือกได้ ถ้าเปิด [BuddhistYearField.showPickerButton]
  input,

  /// แบบเลือก — ช่อง read-only แตะที่ช่อง (หรือไอคอน) เพื่อเปิดรายการปีให้เลือก
  picker,
}

/// ปีงบประมาณ พ.ศ. — ทำงานได้ 2 โหมด
/// - [BuddhistYearFieldMode.input] (ดีฟอลต์) : พิมพ์เอง + มีปุ่มเปิดรายการช่วยเลือก
/// - [BuddhistYearFieldMode.picker] : แตะเพื่อเลือกจากรายการเท่านั้น พิมพ์ไม่ได้
///
/// สร้างผ่าน constructor หลัก หรือใช้ shortcut:
/// - `BuddhistYearField.input(...)`
/// - `BuddhistYearField.picker(...)`
class BuddhistYearField extends StatelessWidget {
  static const double _yearTileExtent = 48;

  final TextEditingController controller;
  final BuddhistYearFieldMode mode;
  final String label;
  final bool required;
  final bool enabled;

  /// แสดงปุ่มเปิดรายการช่วยเลือก (มีผลเฉพาะโหมด [BuddhistYearFieldMode.input])
  /// — ในโหมด [BuddhistYearFieldMode.picker] ปุ่มจะแสดงเสมอ
  final bool showPickerButton;

  final int minYear;
  final int maxYear;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const BuddhistYearField({
    super.key,
    required this.controller,
    this.mode = BuddhistYearFieldMode.input,
    this.label = TransactionUiText.fiscalYearBuddhist,
    this.required = false,
    this.enabled = true,
    this.showPickerButton = true,
    this.minYear = 2500,
    this.maxYear = 2700,
    this.validator,
    this.onChanged,
  });

  /// shortcut สำหรับโหมดกรอกข้อมูล (พิมพ์เอง)
  const BuddhistYearField.input({
    Key? key,
    required TextEditingController controller,
    String label = TransactionUiText.fiscalYearBuddhist,
    bool required = false,
    bool enabled = true,
    bool showPickerButton = true,
    int minYear = 2500,
    int maxYear = 2700,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) : this(
          key: key,
          controller: controller,
          mode: BuddhistYearFieldMode.input,
          label: label,
          required: required,
          enabled: enabled,
          showPickerButton: showPickerButton,
          minYear: minYear,
          maxYear: maxYear,
          validator: validator,
          onChanged: onChanged,
        );

  /// shortcut สำหรับโหมดเลือกจากรายการ (read-only)
  const BuddhistYearField.picker({
    Key? key,
    required TextEditingController controller,
    String label = TransactionUiText.fiscalYearBuddhist,
    bool required = false,
    bool enabled = true,
    int minYear = 2500,
    int maxYear = 2700,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) : this(
          key: key,
          controller: controller,
          mode: BuddhistYearFieldMode.picker,
          label: label,
          required: required,
          enabled: enabled,
          showPickerButton: true,
          minYear: minYear,
          maxYear: maxYear,
          validator: validator,
          onChanged: onChanged,
        );

  static int toGregorian(int buddhistYear) => buddhistYear - 543;
  static int toBuddhist(int gregorianYear) => gregorianYear + 543;

  bool get _isPickerMode => mode == BuddhistYearFieldMode.picker;

  String? _defaultValidator(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) {
      return required ? TransactionUiText.fillRequiredFields : null;
    }
    final n = int.tryParse(t);
    if (n == null || t.length != 4) {
      return TransactionUiText.invalidDataPleaseCheck;
    }
    if (n < minYear || n > maxYear) {
      return '${TransactionUiText.invalidDataPleaseCheck} ($minYear-$maxYear)';
    }
    return null;
  }

  Future<void> _pickYear(BuildContext context) async {
    final currentYear = int.tryParse(controller.text.trim());
    final initialBuddhistYear = (currentYear != null &&
            currentYear >= minYear &&
            currentYear <= maxYear)
        ? currentYear
        : toBuddhist(DateTime.now().year);

    final scrollController = ScrollController(
      initialScrollOffset: ((initialBuddhistYear - minYear) * _yearTileExtent)
          .clamp(0.0, double.maxFinite),
    );
    int? picked;
    try {
      picked = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final tt = theme.textTheme;
          final cs = theme.colorScheme;
          final cancelLabel =
              MaterialLocalizations.of(dialogContext).cancelButtonLabel;
          return SafeArea(
            child: AdaptiveContentSheet(
              title:
                  label.isEmpty ? TransactionUiText.fiscalYearBuddhist : label,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 320,
                        child: Scrollbar(
                          controller: scrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: scrollController,
                            primary: false,
                            itemExtent: _yearTileExtent,
                            itemCount: maxYear - minYear + 1,
                            itemBuilder: (context, index) {
                              final y = minYear + index;
                              final selected = y == initialBuddhistYear;
                              return InkWell(
                                onTap: () => Navigator.pop(dialogContext, y),
                                child: Center(
                                  child: Text(
                                    '$y',
                                    style: tt.titleMedium?.copyWith(
                                      fontFamily: 'Kanit',
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected ? cs.primary : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(cancelLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      scrollController.dispose();
    }
    if (picked == null) return;
    final buddhistYear = picked.toString();
    controller.text = buddhistYear;
    onChanged?.call(buddhistYear);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final showSuffix = enabled && (_isPickerMode || showPickerButton);

    final field = TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: _isPickerMode,
      showCursor: !_isPickerMode,
      keyboardType: _isPickerMode ? TextInputType.none : TextInputType.number,
      inputFormatters: _isPickerMode
          ? const <TextInputFormatter>[]
          : <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
      onTap: (_isPickerMode && enabled) ? () => _pickYear(context) : null,
      validator: validator ?? _defaultValidator,
      onChanged: onChanged,
      textAlign: TextAlign.center,
      style: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontFamily: 'Kanit',
      ),
      decoration: buildAppCapsuleInputDecoration(
        context: context,
        showCounter: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: showSuffix
            ? IconButton(
                tooltip: TransactionUiText.fiscalYearBuddhist,
                icon: Icon(
                  _isPickerMode
                      ? Icons.arrow_drop_down
                      : Icons.format_list_numbered,
                  color: colorScheme.primary,
                ),
                onPressed: () => _pickYear(context),
              )
            : null,
      ),
    );

    if (label.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              fontFamily: 'Kanit',
              fontSize: 13,
            ),
            children: [
              TextSpan(text: label),
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sp4),
        field,
      ],
    );
  }
}
