import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

class AppBusyBackdrop extends StatelessWidget {
  const AppBusyBackdrop({
    super.key,
    required this.child,
    required this.isBusy,
    required this.message,
    this.maxCardWidth = 360,
    this.backdropOpacity = 0.24,
  });

  final Widget child;
  final bool isBusy;
  final String message;
  final double maxCardWidth;
  final double backdropOpacity;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final effectiveMaxWidth = (width - (AppTheme.sp24 * 2)).clamp(260.0, maxCardWidth);

    return Stack(
      children: [
        child,
        if (isBusy)
          Positioned.fill(
            child: AbsorbPointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return Opacity(
                    opacity: t,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 2.5 * t,
                        sigmaY: 2.5 * t,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: backdropOpacity + 0.10),
                              Colors.black.withValues(alpha: backdropOpacity),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: 0.96 + (0.04 * t),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: AppTheme.sp24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.sp16,
                                  vertical: AppTheme.sp16,
                                ),
                                decoration: BoxDecoration(
                                  color: c.cardWhite.withValues(alpha: 0.96),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: c.navy.withValues(alpha: 0.10),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 28,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: c.navy.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.6,
                                          color: c.navy,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.sp12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          message,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: c.textPrimary,
                                            fontSize: 15,
                                            height: 1.35,
                                            fontWeight: FontWeight.w700,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
