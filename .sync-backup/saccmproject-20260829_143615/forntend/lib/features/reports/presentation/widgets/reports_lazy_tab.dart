import 'package:flutter/material.dart';

/// Materialize tab body when visited or prefetched; rebuild on parent updates.
class ReportsLazyTab extends StatefulWidget {
  const ReportsLazyTab({
    super.key,
    required this.shouldMaterialize,
    required this.builder,
  });

  /// True when tab is active or an adjacent tab to prefetch.
  final bool shouldMaterialize;
  final WidgetBuilder builder;

  @override
  State<ReportsLazyTab> createState() => _ReportsLazyTabState();
}

class _ReportsLazyTabState extends State<ReportsLazyTab> {
  bool _materialized = false;

  @override
  void initState() {
    super.initState();
    _materialized = widget.shouldMaterialize;
  }

  @override
  void didUpdateWidget(covariant ReportsLazyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldMaterialize && !_materialized) {
      setState(() => _materialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_materialized) return const SizedBox.shrink();
    return widget.builder(context);
  }
}
