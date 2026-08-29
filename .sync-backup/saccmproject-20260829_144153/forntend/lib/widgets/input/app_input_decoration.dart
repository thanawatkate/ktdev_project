import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

InputDecoration buildAppCapsuleInputDecoration({
  required BuildContext context,
  String? hintText,
  TextStyle? hintStyle,
  Widget? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
  bool showCounter = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  final c = AppColors.of(context);
  const r = BorderRadius.all(Radius.circular(50));
  final defaultSide = BorderSide(color: c.cardBorder, width: 1);

  return InputDecoration(
    hintText: hintText,
    hintStyle: hintStyle ??
        TextStyle(
          color: c.textHint,
          fontSize: 14,
          fontFamily: 'Kanit',
        ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    counterText: showCounter ? null : '',
    contentPadding: contentPadding,
    filled: true,
    fillColor: c.surface,
    prefixIconColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.focused)) return scheme.primary;
      if (states.contains(WidgetState.error)) return scheme.error;
      if (states.contains(WidgetState.disabled)) return c.textHint;
      return c.textSecondary;
    }),
    suffixIconColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.focused)) return scheme.primary;
      if (states.contains(WidgetState.error)) return scheme.error;
      if (states.contains(WidgetState.disabled)) return c.textHint;
      return c.textSecondary;
    }),
    border: OutlineInputBorder(borderRadius: r, borderSide: defaultSide),
    enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: defaultSide),
    focusedBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: scheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: scheme.error, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: c.cardBorder.withValues(alpha: 0.55)),
    ),
  );
}
