import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';

class PageGuideItem {
  const PageGuideItem({
    required this.icon,
    required this.text,
    this.accentColor,
    this.backgroundColor,
  });

  final IconData icon;
  final String text;
  final Color? accentColor;
  final Color? backgroundColor;
}

class PageGuideDialog extends StatelessWidget {
  const PageGuideDialog({
    super.key,
    required this.title,
    this.items = const [],
    this.children = const [],
    this.maxWidth = 520,
  });

  final String title;
  final List<PageGuideItem> items;
  final List<Widget> children;
  final double maxWidth;

  static Future<void> show({
    required BuildContext context,
    required String title,
    List<PageGuideItem> items = const [],
    List<Widget> children = const [],
    double maxWidth = 520,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PageGuideDialog(
        title: title,
        items: items,
        maxWidth: maxWidth,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      for (final item in items) PageGuideCard(item: item),
      ...children,
    ];

    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < content.length; i++) ...[
                if (i > 0) const SizedBox(height: AppTheme.sp12),
                content[i],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(TransactionUiText.close),
        ),
      ],
    );
  }
}

class PageGuideCard extends StatelessWidget {
  const PageGuideCard({
    super.key,
    required this.item,
  });

  final PageGuideItem item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = item.accentColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: item.backgroundColor ?? c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 18, color: accent),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                color: c.textPrimary,
                fontFamily: 'Kanit',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
