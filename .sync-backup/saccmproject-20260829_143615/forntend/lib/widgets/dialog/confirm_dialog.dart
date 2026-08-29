import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

/// Unified confirmation dialog — ใช้แทนทั้ง DeleteConfirmDialog และ ActionConfirmDialog
///
/// - `isDestructive: true` (ค่าเริ่มต้น) → confirm ปุ่ม `FilledButton`
///   พื้นหลัง `confirmColor ?? colorScheme.error` (ใช้กับ: ลบ, ออกจากระบบ)
/// - `isDestructive: false` → confirm ปุ่ม `TextButton`
///   สีข้อความ `confirmColor ?? colorScheme.primary` (ใช้กับ: ยืนยันการกระทำ, ออกโดยไม่บันทึก)
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText = 'ยกเลิก',
    this.icon,
    this.shape,
    this.isDestructive = true,
    this.confirmColor,
    this.onConfirm,
  });

  final String title;
  final String message;
  final String cancelText;
  final String confirmText;

  /// Widget ไอคอนที่แสดงเหนือ title (optional)
  final Widget? icon;

  /// Shape ของ AlertDialog (optional)
  final ShapeBorder? shape;

  /// `true` = FilledButton + error/custom bg; `false` = TextButton + primary/custom text
  final bool isDestructive;

  /// Override สีปุ่ม: ถ้า isDestructive → backgroundColor; ถ้าไม่ใช่ → foregroundColor
  final Color? confirmColor;

  /// Optional custom confirm action. Defaults to `Navigator.pop(context, true)`.
  final VoidCallback? onConfirm;

  static const _fontFamily = 'Kanit';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: shape,
      icon: icon,
      backgroundColor: c.cardWhite,
      title: Text(
        title,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontFamily: _fontFamily,
          color: c.textPrimary,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isDestructive)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor ?? scheme.error,
            ),
            onPressed: onConfirm ?? () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: const TextStyle(fontFamily: _fontFamily),
            ),
          )
        else
          TextButton(
            onPressed: onConfirm ?? () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: confirmColor ?? scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
