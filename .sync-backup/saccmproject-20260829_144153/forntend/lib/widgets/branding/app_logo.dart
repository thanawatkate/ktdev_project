import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

/// โลโก้แอป SACC — ใช้รูปจาก [assetPath] แทน Material icon เดิม
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.borderRadius,
    this.showShadow = true,
    this.semanticLabel = 'โลโก้ระบบบัญชีและการเงินสถานศึกษา',
  });

  static const assetPath = 'assets/images/app_logo.png';

  final double size;
  final double? borderRadius;
  final bool showShadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppTheme.r16;
    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: semanticLabel,
    );

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );

    if (!showShadow) return clipped;

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: size * 0.21,
            offset: Offset(0, size * 0.083),
          ),
        ],
      ),
      child: clipped,
    );
  }
}
