import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../sheet/adaptive_content_sheet.dart';
import 'app_input_decoration.dart';

/// Model สำหรับรายการ dropdown แต่ละตัว
class AppDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leadingIcon;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leadingIcon,
  });
}

enum AppDropdownDensity { compact, comfortable }

/// Dropdown field ที่ดีไซน์สอดคล้องกับ AppInput
/// ใช้ [AppDropdownItem] เป็น data model
class AppDropdownField<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final List<AppDropdownItem<T>> items;
  final T? value;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final bool required;
  final Widget? prefixIcon;
  final String? helperText;
  final AutovalidateMode? autovalidateMode;
  final AppDropdownDensity density;
  final bool isMultiSelect;
  final Set<T> selectedValues;
  final void Function(Set<T>)? onMultiChanged;
  final String? multiSelectTitle;
  final TextStyle? hintStyle;
  final TextStyle? helperStyle;

  const AppDropdownField({
    super.key,
    this.label,
    this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.required = false,
    this.prefixIcon,
    this.helperText,
    this.autovalidateMode,
    this.density = AppDropdownDensity.comfortable,
    this.isMultiSelect = false,
    this.selectedValues = const {},
    this.onMultiChanged,
    this.multiSelectTitle,
    this.hintStyle,
    this.helperStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final c = AppColors.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const menuRadius = 12.0;
    final menuColor = isDark ? c.cardWhite : colorScheme.surface;
    final selectedItemBg = isDark
        ? c.navy.withValues(alpha: 0.20)
        : colorScheme.primary.withValues(alpha: 0.10);
    final isCompact = density == AppDropdownDensity.compact;
    final fieldContentPadding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final itemPadding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    final itemFontSize = isCompact ? 13.0 : 14.0;

    final dropdown = isMultiSelect
        ? _buildMultiSelectField(
            context: context,
            textTheme: textTheme,
            fieldContentPadding: fieldContentPadding,
          )
        : DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 320,
            borderRadius: BorderRadius.circular(menuRadius),
            icon:
                Icon(Icons.keyboard_arrow_down_rounded, color: c.textSecondary),
            autovalidateMode: autovalidateMode,
            validator: validator,
            onChanged: enabled ? onChanged : null,
            dropdownColor: menuColor,
            decoration: buildAppCapsuleInputDecoration(
              context: context,
              hintText: hint,
              hintStyle: hintStyle,
              prefixIcon: prefixIcon,
              showCounter: false,
              contentPadding: fieldContentPadding,
            ),
            selectedItemBuilder: (_) {
              return items.map((item) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: itemFontSize,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                );
              }).toList();
            },
            items: items.asMap().entries.map((entry) {
              final item = entry.value;
              final isSelected = value != null && item.value == value;
              return DropdownMenuItem<T>(
                value: item.value,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: itemPadding,
                  decoration: BoxDecoration(
                    color: isSelected ? selectedItemBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (item.leadingIcon != null) ...[
                        item.leadingIcon!,
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: itemFontSize,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );

    // Wrap with label if provided
    if (label == null || label!.isEmpty) return dropdown;

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
        dropdown,
        if (helperText != null) ...[
          const SizedBox(height: AppTheme.sp4),
          Text(
            helperText!,
            style: helperStyle ??
                textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiSelectField({
    required BuildContext context,
    required TextTheme textTheme,
    required EdgeInsets fieldContentPadding,
  }) {
    final c = AppColors.of(context);
    final selectedLabels = items
        .where((item) => selectedValues.contains(item.value))
        .map((item) => item.label)
        .toList();
    final summary = selectedLabels.isEmpty
        ? (hint ?? 'แตะเพื่อเลือกหลายรายการ')
        : selectedLabels.length <= 2
            ? selectedLabels.join(', ')
            : '${selectedLabels.take(2).join(', ')} และอีก ${selectedLabels.length - 2} รายการ';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? () => _openMultiSelectDialog(context) : null,
      child: InputDecorator(
        decoration: buildAppCapsuleInputDecoration(
          context: context,
          hintText: hint,
          hintStyle: hintStyle,
          prefixIcon: prefixIcon,
          showCounter: false,
          contentPadding: fieldContentPadding,
          suffixIcon:
              Icon(Icons.keyboard_arrow_down_rounded, color: c.textSecondary),
        ),
        child: Text(
          summary,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: selectedLabels.isEmpty ? c.textHint : c.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _openMultiSelectDialog(BuildContext context) async {
    final tempSelected = selectedValues.toSet();
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return SafeArea(
          child: AdaptiveContentSheet(
            title: multiSelectTitle ?? label ?? 'เลือกหลายรายการ',
            maxHeightFactor: 0.88,
            child: StatefulBuilder(
              builder: (_, setInnerState) => Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp16,
                  0,
                  AppTheme.sp16,
                  AppTheme.sp16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setInnerState(() {
                              tempSelected
                                ..clear()
                                ..addAll(items.map((e) => e.value));
                            }),
                            child: const Text('เลือกทั้งหมด'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setInnerState(tempSelected.clear),
                            child: const Text('ล้างทั้งหมด'),
                          ),
                          const Spacer(),
                          Text('เลือก ${tempSelected.length} รายการ'),
                        ],
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: items.map((item) {
                            final checked = tempSelected.contains(item.value);
                            return CheckboxListTile(
                              value: checked,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.label),
                              onChanged: (_) => setInnerState(() {
                                if (checked) {
                                  tempSelected.remove(item.value);
                                } else {
                                  tempSelected.add(item.value);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('ยกเลิก'),
                          ),
                          const SizedBox(width: AppTheme.sp8),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('ยืนยัน'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (applied == true) onMultiChanged?.call(tempSelected);
  }
}
