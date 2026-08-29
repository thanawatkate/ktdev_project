// ignore_for_file: use_build_context_synchronously
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/layout/embedded_home_scaffold.dart';

import '../widgets/register_tabs.dart';

/// หน้าหลัก "ทะเบียนคุม" — รวมทะเบียนคุม 10 ประเภท
///   1. เงินนอกงบประมาณ (13 หมวด)
///   2. หลักฐานขอเบิก
///   3. ใบสำคัญคู่จ่าย
///   4. การจ่ายเช็ค
///   5. สัญญายืมเงิน
///   6. ใบเสร็จรับเงิน
///   7. เงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย
///   8. เงินฝากธนาคาร (กระแสรายวัน)
///   9. สมุดคู่ฝาก ส่วนราชการผู้เบิก
///  10. รับและนำส่งเงินรายได้แผ่นดิน
class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.embeddedInHome = false,
    this.initialTabIndex,
  });

  final bool embeddedInHome;

  /// แท็บเริ่มต้น (0–9) — แท็บเงินประกัน = 6
  final int? initialTabIndex;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  static const String _fontFamily = 'Kanit';

  late TabController _tabController;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    final initial =
        (widget.initialTabIndex ?? 0).clamp(0, RegisterTabs.count - 1);
    _tabController = TabController(
      length: RegisterTabs.count,
      vsync: this,
      initialIndex: initial,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final registerHeaderHeight = screenWidth < 520 ? 224.0 : 152.0;

    final registerTabs = RegisterTabBar(controller: _tabController);

    return EmbeddedHomeScaffold(
      embeddedInHome: widget.embeddedInHome,
      backgroundColor: c.background,
      standaloneAppBar: AppBar(
        toolbarHeight: 52,
        title: Text(
          TransactionUiText.registerPageTitle,
          style: TextStyle(
            fontFamily: _fontFamily,
            color: c.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(registerHeaderHeight),
          child: registerTabs,
        ),
      ),
      embeddedAppBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(registerHeaderHeight),
          child: registerTabs,
        ),
      ),
      body: RegisterTabView(
        controller: _tabController,
        dio: _dio,
      ),
    );
  }
}
