import 'package:flutter/material.dart';
import 'package:saccm/features/approval/presentation/pages/approval_page.dart';
import 'package:saccm/features/expense_req/presentation/widgets/expense_req_widget.dart';
import 'package:saccm/features/forms/presentation/pages/forms_page.dart';
import 'package:saccm/features/help/presentation/pages/usage_flow_helper_page.dart';
import 'package:saccm/features/home/presentation/pages/home_nav_index.dart';
import 'package:saccm/features/register/presentation/pages/register_page.dart';
import 'package:saccm/features/reports/presentation/pages/reports_page.dart';
import 'package:saccm/features/setting/presentation/pages/main/setting_page.dart';
import 'package:saccm/features/home/presentation/widgets/feature_widgets.dart';
import 'package:saccm/features/home/presentation/widgets/home_dashboard.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({
    super.key,
    required this.screenIndex,
    this.onOpenMenuConfiguration,
    this.onOpenSchoolProfile,
    this.onOpenUserManagement,
    this.onOpenBudgetSource,
    this.onOpenIncomeTypeQuickAdd,
    this.onOpenExpenseType,
    this.onOpenChequeAccount,
    this.onOpenPartyManagement,
    this.onOpenMemberManagement,
    this.onOpenReceiptBookRegister,
    this.onOpenFiscalYearOpening,
    this.onOpenAppointmentOrder,
    this.onOpenDocGroupSettings,
    this.onOpenDatabaseMaintenance,
    this.onNavigateFromUsageGuide,
    this.onOpenDepositRegister,
    this.registerInitialTabIndex,
    this.reportsInitialTabIndex,
    this.onOpenReportsDailyClosing,
  });

  final int screenIndex;

  /// เปิดหน้าตั้งค่าเมนูหลักจากคู่มือ (เมื่อมีสิทธิ์)
  final VoidCallback? onOpenMenuConfiguration;

  /// เปิดหน้าข้อมูลโรงเรียนจากคู่มือ
  final VoidCallback? onOpenSchoolProfile;

  final VoidCallback? onOpenUserManagement;

  final VoidCallback? onOpenBudgetSource;

  /// เปิด popup เพิ่มหมวดรายรับจากคู่มือ
  final VoidCallback? onOpenIncomeTypeQuickAdd;

  final VoidCallback? onOpenExpenseType;

  final VoidCallback? onOpenChequeAccount;

  final VoidCallback? onOpenPartyManagement;

  final VoidCallback? onOpenMemberManagement;

  final VoidCallback? onOpenReceiptBookRegister;

  final VoidCallback? onOpenFiscalYearOpening;

  final VoidCallback? onOpenAppointmentOrder;

  final VoidCallback? onOpenDocGroupSettings;

  /// เปิดหน้าจัดการฐานข้อมูลจากคู่มือ
  final VoidCallback? onOpenDatabaseMaintenance;

  /// จากแท็บแผนภาพในคู่มือ — สลับแท็บหลักเมื่อผู้ใช้แตะโหนดที่มีเมนู
  final ValueChanged<int>? onNavigateFromUsageGuide;

  final VoidCallback? onOpenDepositRegister;

  /// แท็บทะเบียนคุมเริ่มต้น (6 = เงินประกัน)
  final int? registerInitialTabIndex;

  /// แท็บรายงานเริ่มต้น (9 = ปิดวัน)
  final int? reportsInitialTabIndex;

  final VoidCallback? onOpenReportsDailyClosing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inputWidth = inputWidthFor(width);

    return switch (screenIndex) {
      HomeNavIndex.home => HomeDashboard(
          onOpenDepositRegister: onOpenDepositRegister,
          onOpenReportsDailyClosing: onOpenReportsDailyClosing,
        ),
      HomeNavIndex.income => IncomeWidget(inputWidth: inputWidth),
      HomeNavIndex.expense => ExpenseWidget(inputWidth: inputWidth),
      HomeNavIndex.expenseReq => const ExpenseReqWidget(),
      HomeNavIndex.loan => const LoanWidget(),
      HomeNavIndex.approval => const ApprovalPage(embeddedInHome: true),
      HomeNavIndex.reports => ReportsPage(
          embeddedInHome: true,
          initialTabIndex: reportsInitialTabIndex,
        ),
      HomeNavIndex.setting => const SettingTab(embeddedInHome: true),
      HomeNavIndex.usageGuide => UsageFlowHelperPage(
          embeddedInHome: true,
          onOpenMenuConfiguration: onOpenMenuConfiguration,
          onOpenSchoolProfile: onOpenSchoolProfile,
          onOpenUserManagement: onOpenUserManagement,
          onOpenBudgetSource: onOpenBudgetSource,
          onOpenIncomeTypeQuickAdd: onOpenIncomeTypeQuickAdd,
          onOpenExpenseType: onOpenExpenseType,
          onOpenChequeAccount: onOpenChequeAccount,
          onOpenPartyManagement: onOpenPartyManagement,
          onOpenMemberManagement: onOpenMemberManagement,
          onOpenReceiptBookRegister: onOpenReceiptBookRegister,
          onOpenFiscalYearOpening: onOpenFiscalYearOpening,
          onOpenAppointmentOrder: onOpenAppointmentOrder,
          onOpenDocGroupSettings: onOpenDocGroupSettings,
          onOpenDatabaseMaintenance: onOpenDatabaseMaintenance,
          onNavigateToNav: onNavigateFromUsageGuide,
        ),
      HomeNavIndex.register => RegisterPage(
          embeddedInHome: true,
          initialTabIndex: registerInitialTabIndex,
        ),
      HomeNavIndex.forms => const FormsPage(embeddedInHome: true),
      _ => const HomeDashboard(),
    };
  }
}
