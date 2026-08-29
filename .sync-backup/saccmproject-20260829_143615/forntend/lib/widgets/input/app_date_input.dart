import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../constants/transaction_ui_text.dart';
import '../../core/utils/thai_date_formatter.dart';
import 'app_input_decoration.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AppDateInput — Date picker widget ที่ใช้ซ้ำได้ (รองรับภาษาไทย + พ.ศ.)
//
// สไตล์:
//   - Pill-shaped (borderRadius 50) แบบเดียวกับ AppInput
//   - ใช้ buildAppCapsuleInputDecoration() → theme-aware colors
//   - Label ด้านบน + helper text ด้านล่าง (เหมือน AppInput)
//   - Clearable suffix icon (ถ้า clearable=true)
//
// ต้องการ:
//   - flutter_localizations: sdk: flutter  ใน pubspec.yaml
//   - GlobalMaterialLocalizations.delegate  ใน MaterialApp
//   - locale: Locale('th', 'TH')            ใน MaterialApp
//
// ใช้งาน:
//   AppDateInput(
//     label: 'วันที่',
//     initialValue: DateTime.now(),
//     onChanged: (date) { /* ... */ },
//   )
//
// Output ตัวอย่าง (dateFormat='thai_buddhist'):
//   "พุธ 6 พฤษภาคม 2569"
//   picker แสดงเดือนไทย + ปี พ.ศ. อัตโนมัติ
// ═══════════════════════════════════════════════════════════════════════════

class AppDateInput extends StatefulWidget {
  /// วันที่เริ่มต้น (ถ้าไม่ระบุจะใช้วันนี้)
  final DateTime? initialValue;

  /// Callback เมื่อเลือกวันที่ใหม่ (null = ล้างค่า)
  final void Function(DateTime?) onChanged;

  /// วันที่แรกที่อนุญาต
  final DateTime? firstDate;

  /// วันที่สุดท้ายที่อนุญาต
  final DateTime? lastDate;

  /// ป้ายชื่อฟิลด์
  final String? label;

  /// ข้อความช่วยเหลือด้านล่างฟิลด์
  final String? helperText;

  /// ข้อความ placeholder เมื่อยังไม่ได้เลือก
  final String? hint;

  /// รูปแบบวันที่ที่แสดง — ใช้ค่าคงที่จาก [AppDateFormat]
  /// - AppDateFormat.thaiBuddhist       → "พุธ 6 พฤษภาคม 2569"  (default)
  /// - AppDateFormat.thaiBuddhistShort  → "6 พ.ค. 2569"
  /// - AppDateFormat.numericBuddhist    → "6/5/2569"
  /// - AppDateFormat.numeric            → "06/05/2026"
  final String dateFormat;

  /// icon นำหน้าฟิลด์
  final Icon? prefixIcon;

  /// ล้างค่าได้หรือไม่
  final bool clearable;

  /// required field แสดงเครื่องหมาย *
  final bool required;

  /// เปิดใช้งานฟิลด์หรือไม่
  final bool enabled;

  const AppDateInput({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.label,
    this.helperText,
    this.hint,
    this.dateFormat = AppDateFormat.thaiBuddhist,
    this.prefixIcon,
    this.clearable = true,
    this.required = false,
    this.enabled = true,
  });

  @override
  State<AppDateInput> createState() => _AppDateInputState();
}

class _AppDateInputState extends State<AppDateInput> {
  late DateTime? _selectedDate;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialValue;
    _controller = TextEditingController(
      text: _selectedDate != null ? _formatDisplayDate(_selectedDate!) : '',
    );
  }

  @override
  void didUpdateWidget(covariant AppDateInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // อัปเดต display เมื่อ initialValue เปลี่ยน (เช่น กรณี edit mode)
    if (oldWidget.initialValue != widget.initialValue) {
      _selectedDate = widget.initialValue;
      _controller.text =
          _selectedDate != null ? _formatDisplayDate(_selectedDate!) : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDisplayDate(DateTime date) {
    return ThaiDateFormatter.formatByPattern(date, widget.dateFormat);
  }

  Future<void> _pickDate() async {
    if (!widget.enabled) return;

    final now = DateTime.now();
    final initial = _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: widget.firstDate ?? DateTime(1900),
      lastDate: widget.lastDate ?? DateTime(2100),
      locale: const Locale('th', 'TH'),
      currentDate: now,
      helpText: TransactionUiText.pickDate,
      cancelText: TransactionUiText.cancel,
      confirmText: TransactionUiText.ok,
      fieldLabelText: TransactionUiText.date,
      fieldHintText: TransactionUiText.dateFieldHint,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: const DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _controller.text = _formatDisplayDate(picked);
      });
      widget.onChanged(picked);
    }
  }

  void _clearDate() {
    if (!widget.enabled) return;

    setState(() {
      _selectedDate = null;
      _controller.clear();
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget field = TextFormField(
      key: ValueKey('app_date_input_${widget.label}_${widget.dateFormat}'),
      controller: _controller,
      enabled: widget.enabled,
      readOnly: true,
      onTap: widget.enabled ? _pickDate : null,
      style: TextStyle(
        fontFamily: 'Kanit',
        fontSize: 14,
        color: c.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: buildAppCapsuleInputDecoration(
        context: context,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon ??
            const Icon(Icons.calendar_today_outlined, size: 18),
        showCounter: false,
        suffixIcon: widget.clearable && _selectedDate != null
            ? IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: c.textHint),
                onPressed: widget.enabled ? _clearDate : null,
                tooltip: TransactionUiText.clearDate,
              )
            : null,
      ),
    );

    // Wrap with label if provided (ใช้โครงสร้างเหมือน AppInput)
    if (widget.label == null || widget.label!.isEmpty) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
              fontFamily: 'Kanit',
              fontSize: 13,
            ),
            children: [
              TextSpan(text: widget.label),
              if (widget.required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sp4),
        field,
        if (widget.helperText != null) ...[
          const SizedBox(height: AppTheme.sp4),
          Text(
            widget.helperText!,
            style: textTheme.bodySmall?.copyWith(
              color: c.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
