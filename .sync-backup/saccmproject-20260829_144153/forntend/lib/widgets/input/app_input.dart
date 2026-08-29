import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/utils/thai_date_formatter.dart';
import '../../constants/app_theme.dart';
import 'app_input_decoration.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AppInputAction — กำหนด "ปุ่ม action" และ behaviour ของ AppInput
//
// ใช้งาน:
//   AppInput(action: AppInputAction.text())           ← กรอกข้อความปกติ
//   AppInput(action: AppInputAction.password())       ← toggle แสดง/ซ่อน
//   AppInput(action: AppInputAction.number())         ← กรอกตัวเลข
//   AppInput(action: AppInputAction.date(...))        ← เปิด date picker
//   AppInput(action: AppInputAction.search(...))      ← autocomplete dropdown
// ═══════════════════════════════════════════════════════════════════════════

// ─── Search item model ───────────────────────────────────────────────────────
class AppInputSearchItem {
  final String id;
  final String label;
  final String? subtitle;

  const AppInputSearchItem({
    required this.id,
    required this.label,
    this.subtitle,
  });

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      other is AppInputSearchItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─── Action sealed class ─────────────────────────────────────────────────────
sealed class AppInputAction {
  const AppInputAction();

  /// ข้อความปกติ — suffix icon เป็น custom หรือไม่มีก็ได้
  const factory AppInputAction.text({Widget? suffixIcon}) = _ActionText;

  /// ตัวเลขเท่านั้น — กรองตัวอักษรออกอัตโนมัติ
  const factory AppInputAction.number({bool allowDecimal, bool obscure}) =
      _ActionNumber;

  /// รหัสผ่าน — suffix ปุ่มแสดง/ซ่อน
  const factory AppInputAction.password() = _ActionPassword;

  /// วันที่ — suffix ปุ่มเปิด calendar + clear
  factory AppInputAction.date({
    DateTime? initialValue,
    DateTime? firstDate,
    DateTime? lastDate,
    required void Function(DateTime?) onChanged,
    String dateFormat,
    bool clearable,
  }) = _ActionDate;

  /// Search / Autocomplete — dropdown รายการที่ตรงกับที่พิมพ์
  const factory AppInputAction.search({
    required List<AppInputSearchItem> items,
    required void Function(AppInputSearchItem) onSelected,
  }) = _ActionSearch;
}

class _ActionText extends AppInputAction {
  final Widget? suffixIcon;
  const _ActionText({this.suffixIcon});
}

class _ActionNumber extends AppInputAction {
  final bool allowDecimal;
  final bool obscure;
  const _ActionNumber({this.allowDecimal = false, this.obscure = false});
}

class _ActionPassword extends AppInputAction {
  const _ActionPassword();
}

class _ActionDate extends AppInputAction {
  final DateTime? initialValue;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final void Function(DateTime?) onChanged;
  final String dateFormat;
  final bool clearable;

  const _ActionDate({
    this.initialValue,
    this.firstDate,
    this.lastDate,
    required this.onChanged,
    this.dateFormat = AppDateFormat.thaiBuddhist,
    this.clearable = true,
  });
}

class _ActionSearch extends AppInputAction {
  final List<AppInputSearchItem> items;
  final void Function(AppInputSearchItem) onSelected;
  const _ActionSearch({required this.items, required this.onSelected});
}

// ═══════════════════════════════════════════════════════════════════════════
// AppInput — widget ตัวเดียว ครบทุก input type
// ═══════════════════════════════════════════════════════════════════════════
class AppInput extends StatefulWidget {
  // ── Common ──────────────────────────────────────────────────────────────────
  final String? label;
  final String? hint;
  final String? helperText;
  final TextStyle? hintStyle;
  final TextStyle? helperStyle;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;
  final bool readOnly;
  final bool required;
  final Widget? prefixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final AutovalidateMode? autovalidateMode;
  final TextAlign textAlign;
  final int maxLines;
  final int? maxLength;
  final int? minLines;
  final TextCapitalization textCapitalization;
  final String? initialValue;

  // ── Action — กำหนด behaviour ────────────────────────────────────────────────
  final AppInputAction action;

  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.hintStyle,
    this.helperStyle,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.required = false,
    this.prefixIcon,
    this.focusNode,
    this.textInputAction,
    this.autovalidateMode,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.maxLength,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
    this.initialValue,
    this.action = const AppInputAction.text(),
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  // password toggle
  bool _obscure = true;

  // date picker internal state
  DateTime? _selectedDate;
  TextEditingController? _dateCtrl;

  // Internal FocusNode — สร้างครั้งเดียว ไม่หายเมื่อ parent rebuild
  late final FocusNode _internalFocusNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    final action = widget.action;
    if (action is _ActionDate) {
      _selectedDate = action.initialValue;
      _dateCtrl = TextEditingController(
        text: _selectedDate != null
            ? ThaiDateFormatter.formatByPattern(
                _selectedDate!,
                action.dateFormat,
              )
            : '',
      );
    }
  }

  @override
  void didUpdateWidget(AppInput old) {
    super.didUpdateWidget(old);
    // sync date value if parent updates initialValue
    final action = widget.action;
    if (action is _ActionDate && action.initialValue != _selectedDate) {
      _selectedDate = action.initialValue;
      _dateCtrl?.text = _selectedDate != null
          ? ThaiDateFormatter.formatByPattern(_selectedDate!, action.dateFormat)
          : '';
    }
  }

  @override
  void dispose() {
    _internalFocusNode.dispose();
    _dateCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    if (action is _ActionSearch) return _buildSearch(action);
    return _buildTextBased(action);
  }

  // ── Inline label wrapper (ไม่ต้องใช้ AppInputWrapper แยกต่างหาก) ─────────────
  Widget _wrap(Widget child) {
    final label = widget.label;
    if (label == null || label.isEmpty) return child;
    final textTheme = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
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
              TextSpan(text: label),
              if (widget.required)
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
        child,
        if (widget.helperText != null) ...[
          const SizedBox(height: AppTheme.sp4),
          Text(
            widget.helperText!,
            style: widget.helperStyle ??
                textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                ),
          ),
        ],
      ],
    );
  }

  // ── Text-based fields (text / password / number / date) ──────────────────────
  Widget _buildTextBased(AppInputAction action) {
    Widget? prefix = widget.prefixIcon;
    Widget? suffix;
    List<TextInputFormatter> formatters = [];
    bool obscure = false;
    bool readOnly = widget.readOnly;
    TextEditingController? ctrl = widget.controller;
    TextInputType? keyboard;
    VoidCallback? tapHandler = widget.onTap;

    switch (action) {
      case _ActionPassword():
        obscure = _obscure;
        prefix ??= const Icon(Icons.lock_outline_rounded);
        suffix = IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure
              ? TransactionUiText.showPassword
              : TransactionUiText.hidePassword,
        );

      case _ActionNumber(:final allowDecimal, obscure: final obscureNumber):
        obscure = obscureNumber && _obscure;
        keyboard = TextInputType.numberWithOptions(decimal: allowDecimal);
        formatters = [
          FilteringTextInputFormatter.allow(
            RegExp(allowDecimal ? r'[0-9.,]' : r'[0-9]'),
          ),
        ];
        if (obscureNumber) {
          suffix = IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
            tooltip: _obscure
                ? TransactionUiText.showPin
                : TransactionUiText.hidePin,
          );
        }

      case _ActionDate(:final clearable):
        readOnly = true;
        ctrl = _dateCtrl;
        prefix ??= const Icon(Icons.calendar_today_outlined);
        tapHandler = widget.enabled ? _pickDate : null;
        suffix = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (clearable && _selectedDate != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.enabled ? _clearDate : null,
                tooltip: TransactionUiText.clearDate,
              ),
            IconButton(
              icon: const Icon(Icons.event_outlined),
              onPressed: widget.enabled ? _pickDate : null,
              tooltip: TransactionUiText.pickDate,
            ),
          ],
        );

      case _ActionText(:final suffixIcon):
        suffix = suffixIcon;

      default:
        break;
    }

    return _wrap(TextFormField(
      key: ValueKey('app_input_${widget.label}_${action.runtimeType}'),
      controller: ctrl,
      initialValue: ctrl == null ? widget.initialValue : null,
      focusNode: _effectiveFocusNode,
      enabled: widget.enabled,
      readOnly: readOnly,
      obscureText: obscure,
      maxLength: widget.maxLength,
      maxLines: obscure ? 1 : widget.maxLines,
      minLines: widget.minLines,
      keyboardType: keyboard,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      textAlign: widget.textAlign,
      inputFormatters: formatters,
      style: TextStyle(
        color: AppColors.of(context).textPrimary,
        fontFamily: 'Kanit',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      autovalidateMode: widget.autovalidateMode,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: tapHandler,
      validator: widget.validator,
      decoration: _capsuleDecoration(
        hintText: widget.hint,
        hintStyle: widget.hintStyle,
        prefixIcon: prefix,
        suffixIcon: suffix,
      ),
    ));
  }

  // ── Capsule decoration helper ────────────────────────────────────────
  InputDecoration _capsuleDecoration({
    String? hintText,
    TextStyle? hintStyle,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return buildAppCapsuleInputDecoration(
      context: context,
      hintText: hintText,
      hintStyle: hintStyle,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      showCounter: false,
    );
  }

  // ── Search / Autocomplete ─────────────────────────────────────────────────────
  Widget _buildSearch(_ActionSearch action) {
    return _wrap(Autocomplete<AppInputSearchItem>(
      displayStringForOption: (option) => option.label,
      fieldViewBuilder: (ctx, controller, node, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: node,
          onEditingComplete: onSubmitted,
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontFamily: 'Kanit',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          validator: widget.validator,
          autovalidateMode: widget.autovalidateMode,
          decoration: _capsuleDecoration(
            hintText: widget.hint ?? TransactionUiText.search,
            hintStyle: widget.hintStyle,
            prefixIcon: widget.prefixIcon ?? const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      node.unfocus();
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (ctx, onSelectedItem, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final item = options.elementAt(i);
                  return ListTile(
                    title: Text(item.label),
                    subtitle:
                        item.subtitle != null ? Text(item.subtitle!) : null,
                    onTap: () => onSelectedItem(item),
                    dense: true,
                  );
                },
              ),
            ),
          ),
        );
      },
      optionsBuilder: (value) {
        if (value.text.isEmpty) return const [];
        final q = value.text.toLowerCase();
        return action.items.where(
          (item) =>
              item.label.toLowerCase().contains(q) ||
              (item.subtitle?.toLowerCase().contains(q) ?? false),
        );
      },
      onSelected: action.onSelected,
    ));
  }

  // ── Date helpers ──────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final dateAction = widget.action as _ActionDate;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: dateAction.firstDate ?? DateTime(1900),
      lastDate: dateAction.lastDate ?? DateTime(now.year + 10),
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
        _dateCtrl!.text =
            ThaiDateFormatter.formatByPattern(picked, dateAction.dateFormat);
      });
      dateAction.onChanged(picked);
    }
  }

  void _clearDate() {
    final dateAction = widget.action as _ActionDate;
    setState(() {
      _selectedDate = null;
      _dateCtrl!.clear();
    });
    dateAction.onChanged(null);
  }
}
