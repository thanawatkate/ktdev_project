import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget? child;

  const CustomCard({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Card(clipBehavior: Clip.hardEdge, child: child);
  }
}
