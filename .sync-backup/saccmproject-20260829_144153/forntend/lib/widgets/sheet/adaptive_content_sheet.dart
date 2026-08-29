import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

/// Bottom sheet shell for short history/detail/log content.
///
/// The sheet grows with its content, caps height at [maxHeightFactor] of the
/// screen, then lets the body scroll inside the capped area.
class AdaptiveContentSheet extends StatelessWidget {
  const AdaptiveContentSheet({
    super.key,
    required this.child,
    this.title,
    this.titleWidget,
    this.showHandle = true,
    this.maxHeightFactor = 0.9,
    this.borderRadius = AppTheme.r16,
    this.titlePadding = const EdgeInsets.fromLTRB(
      AppTheme.sp16,
      AppTheme.sp12,
      AppTheme.sp16,
      AppTheme.sp8,
    ),
  }) : assert(title == null || titleWidget == null);

  final Widget child;
  final String? title;
  final Widget? titleWidget;
  final bool showHandle;
  final double maxHeightFactor;
  final double borderRadius;
  final EdgeInsetsGeometry titlePadding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final screenMaxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableMaxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screenMaxHeight;
        final maxHeight = math.min(availableMaxHeight, screenMaxHeight);

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Material(
              color: c.cardWhite,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHandle) ...[
                    const SizedBox(height: AppTheme.sp8),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                  if (titleWidget != null)
                    Padding(
                      padding: titlePadding,
                      child: titleWidget!,
                    )
                  else if (title != null)
                    Padding(
                      padding: titlePadding,
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
