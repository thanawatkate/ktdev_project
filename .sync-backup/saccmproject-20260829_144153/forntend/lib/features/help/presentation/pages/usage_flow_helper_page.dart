import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/help/data/datasources/startup_readiness_local_data_source.dart';
import 'package:saccm/features/help/presentation/pages/system_flow_diagram_tab.dart';
import 'package:saccm/features/home/presentation/pages/home_nav_index.dart';

/// หน้าคู่มือสรุป flow การใช้งานหลักของระบบ
///
/// เมื่อ [embeddedInHome] เป็น true จะไม่แสดง AppBar ของตัวเอง
/// (ใช้เมื่อฝังใน [HomeRouter] ที่มี AppBar ของหลักอยู่แล้ว)
class UsageFlowHelperPage extends StatefulWidget {
  const UsageFlowHelperPage({
    super.key,
    this.embeddedInHome = false,
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
    this.onNavigateToNav,
  });

  final bool embeddedInHome;

  /// เปิดหน้าตั้งค่าเมนูหลัก (ส่งจาก [HomeRouter] เมื่อผู้ใช้มีสิทธิ์)
  final VoidCallback? onOpenMenuConfiguration;

  /// เปิดหน้าข้อมูลโรงเรียน (ตั้งค่าระบบ → ทั่วไป)
  final VoidCallback? onOpenSchoolProfile;

  /// เปิดหน้าผู้ใช้ระบบ
  final VoidCallback? onOpenUserManagement;

  /// เปิดหน้าแหล่งเงิน
  final VoidCallback? onOpenBudgetSource;

  /// เปิด popup เพิ่มหมวดรายรับ (ตั้งค่าระบบ → ค่าเริ่มต้น)
  final VoidCallback? onOpenIncomeTypeQuickAdd;

  /// เปิดหน้าประเภทรายจ่าย
  final VoidCallback? onOpenExpenseType;

  /// เปิดหน้าบัญชีเช็ค
  final VoidCallback? onOpenChequeAccount;

  /// เปิดหน้าผู้รับ/ผู้จ่าย
  final VoidCallback? onOpenPartyManagement;

  /// เปิดหน้าสมาชิก
  final VoidCallback? onOpenMemberManagement;

  /// เปิดแท็บเล่มใบเสร็จในทะเบียนคุม
  final VoidCallback? onOpenReceiptBookRegister;

  /// เปิดหน้ายอดยกมาต้นปีงบประมาณ
  final VoidCallback? onOpenFiscalYearOpening;

  /// เปิดหน้าคำสั่งแต่งตั้ง
  final VoidCallback? onOpenAppointmentOrder;

  /// เปิดหน้ารูปแบบเลขเอกสาร
  final VoidCallback? onOpenDocGroupSettings;

  /// เปิดหน้าจัดการฐานข้อมูล (ตั้งค่าระบบ)
  final VoidCallback? onOpenDatabaseMaintenance;

  /// สลับแท็บหลักของหน้าแรกไปยัง [HomeNavIndex] (ใช้จากแท็บแผนภาพเมื่อผู้ใช้แตะโหนด)
  final ValueChanged<int>? onNavigateToNav;

  static const _sections = <_FlowSection>[
    _FlowSection(
      icon: Icons.verified_user_outlined,
      iconColorKey: _IconTone.navy,
      title: TransactionUiText.usageFlowS1Title,
      bullets: [
        TransactionUiText.usageFlowS1_1,
        TransactionUiText.usageFlowS1_2,
        TransactionUiText.usageFlowS1_3,
        TransactionUiText.usageFlowS1_4,
      ],
    ),
    _FlowSection(
      icon: Icons.tune_rounded,
      iconColorKey: _IconTone.loan,
      title: TransactionUiText.usageFlowS2Title,
      bullets: [
        TransactionUiText.usageFlowS2_1,
        TransactionUiText.usageFlowS2_2,
        TransactionUiText.usageFlowS2_3,
        TransactionUiText.usageFlowS2_4,
        TransactionUiText.usageFlowS2_5,
      ],
    ),
    _FlowSection(
      icon: Icons.account_balance_wallet_outlined,
      iconColorKey: _IconTone.income,
      title: TransactionUiText.usageFlowS3Title,
      bullets: [
        TransactionUiText.usageFlowS3_1,
        TransactionUiText.usageFlowS3_2,
        TransactionUiText.usageFlowS3_3,
        TransactionUiText.usageFlowS3_3b,
        TransactionUiText.usageFlowS3_4,
      ],
    ),
    _FlowSection(
      icon: Icons.task_alt_rounded,
      iconColorKey: _IconTone.expense,
      title: TransactionUiText.usageFlowS4Title,
      bullets: [
        TransactionUiText.usageFlowS4_1,
        TransactionUiText.usageFlowS4_2,
        TransactionUiText.usageFlowS4_3,
        TransactionUiText.usageFlowS4_4,
      ],
    ),
    _FlowSection(
      icon: Icons.fact_check_outlined,
      iconColorKey: _IconTone.navy,
      title: TransactionUiText.usageFlowS5Title,
      bullets: [
        TransactionUiText.usageFlowS5_0,
        TransactionUiText.usageFlowS5_00,
        TransactionUiText.usageFlowS5_01,
      ],
    ),
    _FlowSection(
      icon: Icons.cloud_sync_outlined,
      iconColorKey: _IconTone.navy,
      title: TransactionUiText.usageFlowS6Title,
      bullets: [
        TransactionUiText.usageFlowS5_1,
        TransactionUiText.usageFlowS5_2,
        TransactionUiText.usageFlowS5_3,
        TransactionUiText.usageFlowS5_4,
      ],
    ),
  ];

  @override
  State<UsageFlowHelperPage> createState() => _UsageFlowHelperPageState();
}

class _UsageFlowHelperPageState extends State<UsageFlowHelperPage> {
  final StartupReadinessLocalDataSource _readinessDs =
      StartupReadinessLocalDataSource();
  late Future<StartupReadinessSnapshot> _readinessFuture;

  @override
  void initState() {
    super.initState();
    _readinessFuture = _readinessDs.load();
  }

  void _reloadReadiness() {
    if (!mounted) return;
    setState(() => _readinessFuture = _readinessDs.load());
  }

  VoidCallback? _refreshingAction(VoidCallback? action) {
    if (action == null) return null;
    return () {
      action();
      Timer(const Duration(milliseconds: 350), _reloadReadiness);
    };
  }

  TabBar _tabBar(BuildContext context, AppColors c) {
    return TabBar(
      labelColor: c.textPrimary,
      unselectedLabelColor: c.textSecondary,
      indicatorColor: c.navy,
      labelStyle: const TextStyle(
        fontFamily: 'Kanit',
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'Kanit',
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      tabs: const [
        Tab(text: TransactionUiText.startupReadinessTabLabel),
        Tab(text: TransactionUiText.usageFlowTabSteps),
        Tab(text: TransactionUiText.usageFlowTabDiagram),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: widget.embeddedInHome
            ? null
            : AppBar(
                title: const Text(
                  TransactionUiText.usageFlowHelperTitle,
                  style: TextStyle(fontFamily: 'Kanit'),
                ),
                backgroundColor: c.cardWhite,
                elevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tabBar(context, c),
                      Divider(height: 1, color: c.cardBorder),
                    ],
                  ),
                ),
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embeddedInHome) ...[
              Material(
                color: c.cardWhite,
                child: _tabBar(context, c),
              ),
              Divider(height: 1, color: c.cardBorder),
            ],
            Expanded(
              child: TabBarView(
                children: [
                  _StartupReadinessTab(
                    c: c,
                    readinessFuture: _readinessFuture,
                    onRefresh: _reloadReadiness,
                    onOpenSchoolProfile:
                        _refreshingAction(widget.onOpenSchoolProfile),
                    onOpenUserManagement:
                        _refreshingAction(widget.onOpenUserManagement),
                    onOpenBudgetSource:
                        _refreshingAction(widget.onOpenBudgetSource),
                    onOpenIncomeTypeQuickAdd:
                        _refreshingAction(widget.onOpenIncomeTypeQuickAdd),
                    onOpenExpenseType:
                        _refreshingAction(widget.onOpenExpenseType),
                    onOpenChequeAccount:
                        _refreshingAction(widget.onOpenChequeAccount),
                    onOpenPartyManagement:
                        _refreshingAction(widget.onOpenPartyManagement),
                    onOpenMemberManagement:
                        _refreshingAction(widget.onOpenMemberManagement),
                    onOpenReceiptBookRegister:
                        _refreshingAction(widget.onOpenReceiptBookRegister),
                    onOpenFiscalYearOpening:
                        _refreshingAction(widget.onOpenFiscalYearOpening),
                    onOpenAppointmentOrder:
                        _refreshingAction(widget.onOpenAppointmentOrder),
                    onOpenDocGroupSettings:
                        _refreshingAction(widget.onOpenDocGroupSettings),
                    onOpenDatabaseMaintenance:
                        _refreshingAction(widget.onOpenDatabaseMaintenance),
                  ),
                  _UsageFlowStepsTab(
                    c: c,
                    onOpenMenuConfiguration: widget.onOpenMenuConfiguration,
                    onOpenSchoolProfile: widget.onOpenSchoolProfile,
                    onOpenIncomeTypeQuickAdd: widget.onOpenIncomeTypeQuickAdd,
                    onOpenDatabaseMaintenance: widget.onOpenDatabaseMaintenance,
                    onNavigateToNav: widget.onNavigateToNav,
                    sections: UsageFlowHelperPage._sections,
                  ),
                  SystemFlowDiagramTab(onNavigateToNav: widget.onNavigateToNav),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StartupStatus { ready, attention, missing }

class _StartupChecklistEntry {
  const _StartupChecklistEntry({
    required this.title,
    required this.description,
    required this.details,
    required this.icon,
    required this.status,
    this.onTap,
  });

  final String title;
  final String description;
  final List<String> details;
  final IconData icon;
  final _StartupStatus status;
  final VoidCallback? onTap;
}

class _StartupChecklistSection {
  const _StartupChecklistSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_StartupChecklistEntry> items;
}

class _StartupReadinessTab extends StatelessWidget {
  const _StartupReadinessTab({
    required this.c,
    required this.readinessFuture,
    required this.onRefresh,
    required this.onOpenSchoolProfile,
    required this.onOpenUserManagement,
    required this.onOpenBudgetSource,
    required this.onOpenIncomeTypeQuickAdd,
    required this.onOpenExpenseType,
    required this.onOpenChequeAccount,
    required this.onOpenPartyManagement,
    required this.onOpenMemberManagement,
    required this.onOpenReceiptBookRegister,
    required this.onOpenFiscalYearOpening,
    required this.onOpenAppointmentOrder,
    required this.onOpenDocGroupSettings,
    required this.onOpenDatabaseMaintenance,
  });

  static final NumberFormat _moneyFmt = NumberFormat('#,##0.00');

  final AppColors c;
  final Future<StartupReadinessSnapshot> readinessFuture;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenSchoolProfile;
  final VoidCallback? onOpenUserManagement;
  final VoidCallback? onOpenBudgetSource;
  final VoidCallback? onOpenIncomeTypeQuickAdd;
  final VoidCallback? onOpenExpenseType;
  final VoidCallback? onOpenChequeAccount;
  final VoidCallback? onOpenPartyManagement;
  final VoidCallback? onOpenMemberManagement;
  final VoidCallback? onOpenReceiptBookRegister;
  final VoidCallback? onOpenFiscalYearOpening;
  final VoidCallback? onOpenAppointmentOrder;
  final VoidCallback? onOpenDocGroupSettings;
  final VoidCallback? onOpenDatabaseMaintenance;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StartupReadinessSnapshot>(
      future: readinessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: c.navy),
                const SizedBox(height: AppTheme.sp12),
                Text(
                  TransactionUiText.startupReadinessLoading,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'Kanit',
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                TransactionUiText.startupReadinessEmptyAction,
                style: TextStyle(fontFamily: 'Kanit'),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final sections = _sectionsFor(data);
        final allItems = sections.expand((section) => section.items).toList();
        final readyCount =
            allItems.where((item) => item.status == _StartupStatus.ready).length;
        final needsWork = allItems.length - readyCount;

        return ListView(
          padding: const EdgeInsets.all(AppTheme.sp16),
          children: [
            _introCard(context, data, readyCount, allItems.length, needsWork),
            const SizedBox(height: AppTheme.sp16),
            for (final section in sections) ...[
              _sectionLabel(section.title),
              const SizedBox(height: AppTheme.sp8),
              _sectionCard(context, section.items),
              const SizedBox(height: AppTheme.sp16),
            ],
          ],
        );
      },
    );
  }

  List<_StartupChecklistSection> _sectionsFor(
    StartupReadinessSnapshot data,
  ) {
    return [
      _StartupChecklistSection(
        title: TransactionUiText.startupReadinessRequiredSection,
        items: [
          _StartupChecklistEntry(
            title: TransactionUiText.schoolProfileTitle,
            description: TransactionUiText.startupSchoolProfileDesc,
            details: [
              data.hasSchoolProfile
                  ? TransactionUiText.startupSchoolProfileReadyDetail
                  : TransactionUiText.startupSchoolProfileMissingDetail,
              if (data.schoolName.isNotEmpty) data.schoolName,
              if (data.schoolAddress.isNotEmpty) data.schoolAddress,
            ],
            icon: Icons.school_rounded,
            status: data.hasSchoolProfile
                ? _StartupStatus.ready
                : _StartupStatus.missing,
            onTap: onOpenSchoolProfile,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.budgetSourceTitle,
            description: TransactionUiText.startupBudgetSourceDesc,
            details: [
              TransactionUiText.startupReadinessFiscalYear(data.fiscalYear),
              TransactionUiText.startupReadinessCount(
                TransactionUiText.budgetSourceTitle,
                data.budgetSourceCount,
              ),
              if (data.budgetSourceTotalAmount <= 0)
                TransactionUiText.startupBudgetSourceZeroAmountDetail
              else
                TransactionUiText.startupReadinessAmount(
                  TransactionUiText.summaryTotal,
                  _moneyFmt.format(data.budgetSourceTotalAmount),
                ),
            ],
            icon: Icons.account_balance_outlined,
            status: data.budgetSourceCount == 0
                ? _StartupStatus.missing
                : data.budgetSourceTotalAmount <= 0
                    ? _StartupStatus.attention
                    : _StartupStatus.ready,
            onTap: onOpenBudgetSource,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.incomeTypeTitle,
            description: TransactionUiText.startupIncomeTypeDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.incomeTypeTitle,
                data.incomeTypeCount,
              ),
              TransactionUiText.startupReadinessCount(
                TransactionUiText.registerOffBudgetTabLabel,
                data.offBudgetIncomeTypeCount,
              ),
              data.linkedIncomeTypeCount > 0
                  ? TransactionUiText.startupReadinessCount(
                      TransactionUiText.budgetSourceTitle,
                      data.linkedIncomeTypeCount,
                    )
                  : TransactionUiText.startupIncomeTypeLinkMissingDetail,
            ],
            icon: Icons.account_balance_wallet_rounded,
            status: data.incomeTypeCount == 0
                ? _StartupStatus.missing
                : data.linkedIncomeTypeCount == 0 ||
                        data.offBudgetIncomeTypeCount < 13
                    ? _StartupStatus.attention
                    : _StartupStatus.ready,
            onTap: onOpenIncomeTypeQuickAdd,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.expenseTypeTitle,
            description: TransactionUiText.startupExpenseTypeDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.expenseTypeTitle,
                data.expenseTypeCount,
              ),
            ],
            icon: Icons.receipt_long_rounded,
            status: data.expenseTypeCount == 0
                ? _StartupStatus.missing
                : data.expenseTypeCount < 9
                    ? _StartupStatus.attention
                    : _StartupStatus.ready,
            onTap: onOpenExpenseType,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.expenseMoneyChannelTitle,
            description: TransactionUiText.startupMoneyChannelDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.expenseMoneyChannelTitle,
                data.moneyTypeCount,
              ),
            ],
            icon: Icons.payments_rounded,
            status: data.moneyTypeCount >= 3
                ? _StartupStatus.ready
                : _StartupStatus.missing,
          ),
        ],
      ),
      _StartupChecklistSection(
        title: TransactionUiText.startupReadinessPeopleSection,
        items: [
          _StartupChecklistEntry(
            title: TransactionUiText.systemUsers,
            description: TransactionUiText.startupUsersDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.systemUsers,
                data.activeUserCount,
              ),
              if (data.passwordChangeRequiredCount > 0)
                TransactionUiText.startupReadinessCount(
                  TransactionUiText.startupReadinessAttention,
                  data.passwordChangeRequiredCount,
                ),
            ],
            icon: Icons.manage_accounts_rounded,
            status: data.activeUserCount == 0
                ? _StartupStatus.missing
                : data.passwordChangeRequiredCount > 0
                    ? _StartupStatus.attention
                    : _StartupStatus.ready,
            onTap: onOpenUserManagement,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.partyPayeePayerTitle,
            description: TransactionUiText.startupPartyDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.partyPayeePayerTitle,
                data.partyCount,
              ),
            ],
            icon: Icons.people_alt_rounded,
            status: data.partyCount > 0
                ? _StartupStatus.ready
                : _StartupStatus.missing,
            onTap: onOpenPartyManagement,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.members,
            description: TransactionUiText.startupMemberDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.members,
                data.memberCount,
              ),
            ],
            icon: Icons.groups_rounded,
            status: data.memberCount > 0
                ? _StartupStatus.ready
                : _StartupStatus.attention,
            onTap: onOpenMemberManagement,
          ),
        ],
      ),
      _StartupChecklistSection(
        title: TransactionUiText.startupReadinessFinanceSection,
        items: [
          _StartupChecklistEntry(
            title: TransactionUiText.chequeAccountPageTitle,
            description: TransactionUiText.startupChequeAccountDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.chequeAccountPageTitle,
                data.chequeAccountCount,
              ),
              TransactionUiText.startupReadinessCount(
                TransactionUiText.bankAccount,
                data.bankAccountCount,
              ),
            ],
            icon: Icons.account_balance_rounded,
            status: data.chequeAccountCount > 0 || data.bankAccountCount > 0
                ? _StartupStatus.ready
                : _StartupStatus.attention,
            onTap: onOpenChequeAccount,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.registerReceiptBookTabLabel,
            description: TransactionUiText.startupReceiptBookDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.registerReceiptBookTabLabel,
                data.availableReceiptBookCount,
              ),
            ],
            icon: Icons.confirmation_number_outlined,
            status: data.availableReceiptBookCount > 0
                ? _StartupStatus.ready
                : _StartupStatus.attention,
            onTap: onOpenReceiptBookRegister,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.fiscalYearOpeningTitle,
            description: TransactionUiText.startupOpeningBalanceDesc,
            details: [
              TransactionUiText.startupReadinessFiscalYear(data.fiscalYear),
              data.fiscalYearOpeningCount == 0 ||
                      data.fiscalYearOpeningTotal == 0
                  ? TransactionUiText.startupOpeningBalanceOptionalDetail
                  : TransactionUiText.startupReadinessAmount(
                      TransactionUiText.summaryTotal,
                      _moneyFmt.format(data.fiscalYearOpeningTotal),
                    ),
            ],
            icon: Icons.compare_arrows_rounded,
            status: data.fiscalYearOpeningCount > 0 &&
                    data.fiscalYearOpeningTotal > 0
                ? _StartupStatus.ready
                : _StartupStatus.attention,
            onTap: onOpenFiscalYearOpening,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.cashKeepingLimitTitle,
            description: TransactionUiText.startupCashLimitDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.cashKeepingLimitTitle,
                data.cashKeepingLimitCount,
              ),
            ],
            icon: Icons.savings_outlined,
            status: data.cashKeepingLimitCount >= 8
                ? _StartupStatus.ready
                : _StartupStatus.missing,
          ),
        ],
      ),
      _StartupChecklistSection(
        title: TransactionUiText.startupReadinessOperationSection,
        items: [
          _StartupChecklistEntry(
            title: TransactionUiText.docGroupSettingsTitle,
            description: TransactionUiText.startupDocGroupDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.docGroupSettingsTitle,
                data.docGroupCount,
              ),
            ],
            icon: Icons.pin_outlined,
            status: data.docGroupCount >= 5
                ? _StartupStatus.ready
                : _StartupStatus.missing,
            onTap: onOpenDocGroupSettings,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.appointmentOrderPageTitle,
            description: TransactionUiText.startupAppointmentDesc,
            details: [
              TransactionUiText.startupReadinessCount(
                TransactionUiText.appointmentOrderPageTitle,
                data.appointmentOrderCount,
              ),
            ],
            icon: Icons.assignment_ind_outlined,
            status: data.appointmentOrderCount > 0
                ? _StartupStatus.ready
                : _StartupStatus.attention,
            onTap: onOpenAppointmentOrder,
          ),
          _StartupChecklistEntry(
            title: TransactionUiText.databaseMaintenanceTitle,
            description: TransactionUiText.startupBackupDesc,
            details: const [TransactionUiText.startupBackupManualDetail],
            icon: Icons.backup_rounded,
            status: _StartupStatus.attention,
            onTap: onOpenDatabaseMaintenance,
          ),
        ],
      ),
    ];
  }

  Widget _introCard(
    BuildContext context,
    StartupReadinessSnapshot data,
    int readyCount,
    int totalCount,
    int needsWork,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.iconBgIncome,
              borderRadius: BorderRadius.circular(AppTheme.r12),
            ),
            child: Icon(Icons.fact_check_outlined, color: c.navy, size: 22),
          ),
          const SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TransactionUiText.startupReadinessTitle,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  TransactionUiText.startupReadinessIntro,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: AppTheme.sp12),
                Wrap(
                  spacing: AppTheme.sp8,
                  runSpacing: AppTheme.sp8,
                  children: [
                    _summaryChip(
                      TransactionUiText.startupReadinessSummary(
                        ready: readyCount,
                        total: totalCount,
                        needsWork: needsWork,
                      ),
                      c.navy,
                    ),
                    _summaryChip(
                      TransactionUiText.startupReadinessFiscalYear(
                        data.fiscalYear,
                      ),
                      Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: TransactionUiText.startupReadinessEmptyAction,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Kanit',
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        fontFamily: 'Kanit',
      ),
    );
  }

  Widget _sectionCard(BuildContext context, List<_StartupChecklistEntry> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 920
            ? (constraints.maxWidth - AppTheme.sp12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppTheme.sp12,
          runSpacing: AppTheme.sp12,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _StartupChecklistCard(item: item, c: c),
              ),
          ],
        );
      },
    );
  }
}

class _StartupChecklistCard extends StatelessWidget {
  const _StartupChecklistCard({
    required this.item,
    required this.c,
  });

  final _StartupChecklistEntry item;
  final AppColors c;

  Color _statusColor() {
    return switch (item.status) {
      _StartupStatus.ready => c.incomeGreen,
      _StartupStatus.attention => c.loanAmber,
      _StartupStatus.missing => c.expenseRed,
    };
  }

  String _statusText() {
    return switch (item.status) {
      _StartupStatus.ready => TransactionUiText.startupReadinessReady,
      _StartupStatus.attention => TransactionUiText.startupReadinessAttention,
      _StartupStatus.missing => TransactionUiText.startupReadinessMissing,
    };
  }

  String _actionText() {
    return item.status == _StartupStatus.ready
        ? TransactionUiText.startupReadinessReviewPage
        : TransactionUiText.startupReadinessOpenPage;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return Material(
      color: c.cardWhite,
      borderRadius: BorderRadius.circular(AppTheme.r16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.sp16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.r16),
            border: Border.all(color: c.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(AppTheme.r12),
                    ),
                    child: Icon(item.icon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: AppTheme.sp12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Kanit',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(statusColor),
                ],
              ),
              if (item.details.isNotEmpty) ...[
                const SizedBox(height: AppTheme.sp12),
                for (final detail in item.details.where((e) => e.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: c.textHint,
                        ),
                        const SizedBox(width: AppTheme.sp8),
                        Expanded(
                          child: Text(
                            detail,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12.5,
                              height: 1.35,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: AppTheme.sp12),
              if (item.onTap != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: item.onTap,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(
                      _actionText(),
                      style: const TextStyle(fontFamily: 'Kanit'),
                    ),
                  ),
                )
              else
                Text(
                  TransactionUiText.startupReadinessNoPageAccess,
                  style: TextStyle(
                    color: c.textHint,
                    fontSize: 12,
                    fontFamily: 'Kanit',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusText(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Kanit',
        ),
      ),
    );
  }
}

class _UsageFlowStepsTab extends StatelessWidget {
  const _UsageFlowStepsTab({
    required this.c,
    required this.onOpenMenuConfiguration,
    required this.onOpenSchoolProfile,
    required this.onOpenIncomeTypeQuickAdd,
    required this.onOpenDatabaseMaintenance,
    required this.onNavigateToNav,
    required this.sections,
  });

  final AppColors c;
  final VoidCallback? onOpenMenuConfiguration;
  final VoidCallback? onOpenSchoolProfile;
  final VoidCallback? onOpenIncomeTypeQuickAdd;
  final VoidCallback? onOpenDatabaseMaintenance;
  final ValueChanged<int>? onNavigateToNav;
  final List<_FlowSection> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.sp16),
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.sp16),
          decoration: BoxDecoration(
            color: c.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.r16),
            border: Border.all(color: c.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.iconBgIncome,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                ),
                child: Icon(Icons.map_outlined, color: c.navy, size: 22),
              ),
              const SizedBox(width: AppTheme.sp12),
              Expanded(
                child: Text(
                  TransactionUiText.usageFlowHelperIntro,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sp16),
        if (onOpenSchoolProfile != null) ...[
          Material(
            color: c.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.r16),
            child: InkWell(
              onTap: onOpenSchoolProfile,
              borderRadius: BorderRadius.circular(AppTheme.r16),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.sp16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.r16),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppTheme.sp12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TransactionUiText.schoolProfileTitle,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TransactionUiText.schoolProfileSubtitle,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textHint),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp16),
        ],
        if (onOpenMenuConfiguration != null) ...[
          Material(
            color: c.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.r16),
            child: InkWell(
              onTap: onOpenMenuConfiguration,
              borderRadius: BorderRadius.circular(AppTheme.r16),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.sp16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.r16),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.menu_open_rounded,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppTheme.sp12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TransactionUiText.menuConfigurationTitle,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TransactionUiText.menuConfigurationSubtitle,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textHint),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp16),
        ],
        if (onOpenIncomeTypeQuickAdd != null) ...[
          Material(
            color: c.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.r16),
            child: InkWell(
              onTap: onOpenIncomeTypeQuickAdd,
              borderRadius: BorderRadius.circular(AppTheme.r16),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.sp16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.r16),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppTheme.sp12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TransactionUiText.incomeTypeQuickAddTitle,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TransactionUiText.incomeTypeQuickAddSubtitle,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textHint),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp16),
        ],
        if (onOpenDatabaseMaintenance != null) ...[
          Material(
            color: c.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.r16),
            child: InkWell(
              onTap: onOpenDatabaseMaintenance,
              borderRadius: BorderRadius.circular(AppTheme.r16),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.sp16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.r16),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.backup_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppTheme.sp12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TransactionUiText.databaseMaintenanceTitle,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TransactionUiText.databaseMaintenanceSubtitle,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textHint),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp16),
        ],
        for (var i = 0; i < sections.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.sp12),
            child: _SectionCard(section: sections[i], c: c),
          ),
          if (i == 2 && onNavigateToNav != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sp12),
              child: _UsageFlowTransactionShortcuts(
                c: c,
                onNavigateToNav: onNavigateToNav!,
              ),
            ),
          if (i == 3 && onNavigateToNav != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sp12),
              child: _UsageFlowNavShortcutCard(
                c: c,
                title: TransactionUiText.usageFlowApprovalShortcutTitle,
                subtitle: TransactionUiText.usageFlowApprovalShortcutSubtitle,
                icon: Icons.task_alt_rounded,
                iconColor: c.expenseRed,
                onTap: () => onNavigateToNav!(HomeNavIndex.approval),
              ),
            ),
          if (i == 4 && onNavigateToNav != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sp12),
              child: _UsageFlowNavShortcutCard(
                c: c,
                title: TransactionUiText.usageFlowFormsShortcutTitle,
                subtitle: TransactionUiText.usageFlowFormsShortcutSubtitle,
                icon: Icons.description_outlined,
                iconColor: Theme.of(context).colorScheme.primary,
                onTap: () => onNavigateToNav!(HomeNavIndex.forms),
              ),
            ),
        ],
      ],
    );
  }
}

/// หลังหัวข้อ “อนุมัติและรายงาน” / “ทะเบียนคุมและแบบฟอร์ม” — สลับแท็บหลักได้ทันที
class _UsageFlowNavShortcutCard extends StatelessWidget {
  const _UsageFlowNavShortcutCard({
    required this.c,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final AppColors c;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: c.cardWhite,
      borderRadius: BorderRadius.circular(AppTheme.r16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.sp16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.r16),
            border: Border.all(color: c.cardBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: AppTheme.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// หลังหัวข้อ “ภาพรวมและธุรกรรม” — ให้แตะไปแท็บรับเงิน/เบิกเงินได้ทันที
class _UsageFlowTransactionShortcuts extends StatelessWidget {
  const _UsageFlowTransactionShortcuts({
    required this.c,
    required this.onNavigateToNav,
  });

  final AppColors c;
  final ValueChanged<int> onNavigateToNav;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      padding: const EdgeInsets.all(AppTheme.sp16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TransactionUiText.usageFlowTransactionShortcutsTitle,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            TransactionUiText.usageFlowTransactionShortcutsHint,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.4,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: AppTheme.sp12),
          Wrap(
            spacing: AppTheme.sp8,
            runSpacing: AppTheme.sp8,
            children: [
              SizedBox(
                width: 280,
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                  child: InkWell(
                    onTap: () => onNavigateToNav(HomeNavIndex.income),
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.sp12,
                        horizontal: AppTheme.sp8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.south_rounded, color: primary, size: 20),
                          const SizedBox(width: AppTheme.sp8),
                          Expanded(
                            child: Text(
                              TransactionUiText.incomeRecord,
                              style: TextStyle(
                                fontFamily: 'Kanit',
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: c.textHint),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                  child: InkWell(
                    onTap: () => onNavigateToNav(HomeNavIndex.expenseReq),
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.sp12,
                        horizontal: AppTheme.sp8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.request_quote_outlined,
                              color: c.loanAmber, size: 20),
                          const SizedBox(width: AppTheme.sp8),
                          Expanded(
                            child: Text(
                              TransactionUiText.expenseReqTabLabel,
                              style: TextStyle(
                                fontFamily: 'Kanit',
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: c.textHint),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                  child: InkWell(
                    onTap: () => onNavigateToNav(HomeNavIndex.expense),
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.sp12,
                        horizontal: AppTheme.sp8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.north_rounded,
                              color: c.expenseRed, size: 20),
                          const SizedBox(width: AppTheme.sp8),
                          Expanded(
                            child: Text(
                              TransactionUiText.expenseVoucherRecord,
                              style: TextStyle(
                                fontFamily: 'Kanit',
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: c.textHint),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppTheme.r12),
                  child: InkWell(
                    onTap: () => onNavigateToNav(HomeNavIndex.loan),
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.sp12,
                        horizontal: AppTheme.sp8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.request_quote_rounded,
                            color: c.loanAmber,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.sp8),
                          Expanded(
                            child: Text(
                              TransactionUiText.usageFlowLoanShortcutTitle,
                              style: TextStyle(
                                fontFamily: 'Kanit',
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: c.textHint),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _IconTone { navy, income, expense, loan }

class _FlowSection {
  const _FlowSection({
    required this.icon,
    required this.iconColorKey,
    required this.title,
    required this.bullets,
  });

  final IconData icon;
  final _IconTone iconColorKey;
  final String title;
  final List<String> bullets;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.c});

  final _FlowSection section;
  final AppColors c;

  Color get _iconColor => switch (section.iconColorKey) {
        _IconTone.navy => c.navy,
        _IconTone.income => c.incomeGreen,
        _IconTone.expense => c.expenseRed,
        _IconTone.loan => c.loanAmber,
      };

  Color get _iconBg => switch (section.iconColorKey) {
        _IconTone.navy => c.iconBgIncome,
        _IconTone.income => c.iconBgIncome,
        _IconTone.expense => c.iconBgExpense,
        _IconTone.loan => c.iconBgLoan,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                  ),
                  child: Icon(section.icon, color: _iconColor, size: 20),
                ),
                const SizedBox(width: AppTheme.sp12),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp12),
            for (var i = 0; i < section.bullets.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTheme.sp8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: c.navy.withValues(alpha: 0.75),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      section.bullets[i],
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
