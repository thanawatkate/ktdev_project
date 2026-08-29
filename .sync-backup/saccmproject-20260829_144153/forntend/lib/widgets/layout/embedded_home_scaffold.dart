import 'package:flutter/material.dart';

/// Scaffold กลางสำหรับหน้าที่เปิดได้ทั้งแบบ standalone และ embedded ใน Home.
class EmbeddedHomeScaffold extends StatelessWidget {
  const EmbeddedHomeScaffold({
    super.key,
    required this.embeddedInHome,
    required this.body,
    this.backgroundColor,
    this.standaloneAppBar,
    this.embeddedAppBar,
  });

  final bool embeddedInHome;
  final Widget body;
  final Color? backgroundColor;
  final PreferredSizeWidget? standaloneAppBar;
  final PreferredSizeWidget? embeddedAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: embeddedInHome ? embeddedAppBar : standaloneAppBar,
      body: body,
    );
  }
}
