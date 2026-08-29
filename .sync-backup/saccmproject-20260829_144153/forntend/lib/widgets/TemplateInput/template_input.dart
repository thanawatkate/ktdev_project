import 'package:flutter/material.dart';

class TemplateInput extends StatelessWidget {
  final Widget child;
  final String? title;
  const TemplateInput({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(title!), child],
    );
  }
}
