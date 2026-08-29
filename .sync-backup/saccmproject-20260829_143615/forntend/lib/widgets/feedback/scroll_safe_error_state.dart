import 'package:flutter/material.dart';

class ScrollSafeErrorState extends StatelessWidget {
  const ScrollSafeErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.retryLabel,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.titleColor,
    required this.messageColor,
    required this.buttonColor,
    this.icon = Icons.error_outline_rounded,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color titleColor;
  final Color messageColor;
  final Color buttonColor;
  final IconData icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      color: messageColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(backgroundColor: buttonColor),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      retryLabel,
                      style: const TextStyle(
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
