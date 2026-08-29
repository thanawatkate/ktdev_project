import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

class UserResponsiveFormField {
  const UserResponsiveFormField({
    required this.child,
    this.span = 1,
  });

  final Widget child;
  final int span;
}

double userCardContentWidth(double cardWidth) {
  final horizontalPadding = AppTheme.sp16 * 2;
  return cardWidth > horizontalPadding
      ? cardWidth - horizontalPadding
      : cardWidth;
}

int userResponsiveColumnCount(double maxWidth) {
  if (maxWidth >= 1180) return 4;
  if (maxWidth >= 900) return 3;
  if (maxWidth >= 560) return 2;
  return 1;
}

class UserResponsiveFieldGrid extends StatelessWidget {
  const UserResponsiveFieldGrid({
    super.key,
    required this.maxWidth,
    required this.columnCount,
    required this.fields,
    this.spacing = AppTheme.sp12,
  });

  final double maxWidth;
  final int columnCount;
  final List<UserResponsiveFormField> fields;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final columns = columnCount.clamp(1, 4).toInt();
    final columnWidth = (maxWidth - (spacing * (columns - 1))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: fields.map((field) {
        final span = field.span.clamp(1, columns).toInt();
        final width = (columnWidth * span) + (spacing * (span - 1));
        return SizedBox(
          width: width,
          child: field.child,
        );
      }).toList(),
    );
  }
}
